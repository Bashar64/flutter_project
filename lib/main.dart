import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaskApp());
}
//test push omar
class TaskApp extends StatelessWidget {

  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => TaskState()),
      ],
      child: MaterialApp(
        title: 'Tasker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const RootRouter(),
        routes: {
          LoginScreen.route: (_) => const LoginScreen(),
          SignUpScreen.route: (_) => const SignUpScreen(),
          TaskEditorScreen.route: (_) => const TaskEditorScreen(),
          CalendarScreen.route: (_) => const CalendarScreen(),
          ProfileScreen.route: (_) => const ProfileScreen(),
        },
      ),
    );
  }
}

// Firebase Auth integration
class AuthState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  String? get email => _user?.email;
  String? get username => _user?.displayName;

  AuthState() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    }
  }

  Future<String?> signUp(String email, String password, String username) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update the user's display name with the username
      await credential.user?.updateDisplayName(username);
      await credential.user?.reload();
      _user = _auth.currentUser; // Refresh the user data
      notifyListeners();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed';
    }
  }

  Future<String?> updateUsername(String newUsername) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      print('Updating username to: $newUsername'); // Debug log
      await user.updateDisplayName(newUsername);
      print('Display name updated'); // Debug log
      await user.reload();
      print('User reloaded'); // Debug log
      _user = _auth.currentUser; // Refresh the user data
      print('User data refreshed: ${_user?.displayName}'); // Debug log
      notifyListeners();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}'); // Debug log
      return e.message ?? 'Failed to update username';
    } catch (e) {
      print('General error: $e'); // Debug log
      return 'An error occurred while updating username: $e';
    }
  }

  Future<String?> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      // Delete user's tasks from Firestore first
      final firestore = FirebaseFirestore.instance;
      final tasksCollection = firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks');

      final tasksDocs = await tasksCollection.get();
      for (var doc in tasksDocs.docs) {
        await doc.reference.delete();
      }

      // Delete the user document
      await firestore.collection('users').doc(user.uid).delete();

      // Delete the Firebase Auth user account
      await user.delete();

      _user = null;
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please log in again before deleting your account for security reasons.';
      }
      return e.message ?? 'Failed to delete account';
    } catch (e) {
      return 'An error occurred while deleting your account';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const TaskHomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// Task model
class TaskItem {
  TaskItem({
    required this.id,
    required this.name,
    required this.dateTime,
    this.description,
    this.isCompleted = false,
  });

  final String id;
  final String name;
  final DateTime dateTime;
  final String? description;
  final bool isCompleted;

  TaskItem copyWith({
    String? id,
    String? name,
    DateTime? dateTime,
    String? description,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id ?? this.id,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'],
      name: map['name'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      description: map['description'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class TaskState extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<TaskItem> _tasks = [];

  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  String? get _userId => _auth.currentUser?.uid;

  TaskState() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadTasks();
      } else {
        _tasks = [];
        notifyListeners();
      }
    });
  }

  Future<void> _loadTasks() async {
    if (_userId == null) return;

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('tasks')
              .get();

      _tasks =
          snapshot.docs.map((doc) => TaskItem.fromMap(doc.data())).toList();

      notifyListeners();
    } catch (e) {
      // Error loading tasks: $e
    }
  }

  Future<void> addOrUpdate(TaskItem task) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(task.id)
          .set(task.toMap());

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) {
        _tasks.add(task);
      } else {
        _tasks[index] = task;
      }
      notifyListeners();
    } catch (e) {
      // Error saving task: $e
    }
  }

  Future<void> toggleTaskCompletion(String id) async {
    if (_userId == null) return;

    try {
      final taskIndex = _tasks.indexWhere((t) => t.id == id);
      if (taskIndex == -1) return;

      final task = _tasks[taskIndex];
      final updatedTask = task.copyWith(isCompleted: !task.isCompleted);

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(id)
          .update({'isCompleted': updatedTask.isCompleted});

      _tasks[taskIndex] = updatedTask;
      notifyListeners();
    } catch (e) {
      // Error toggling task completion: $e
    }
  }

  Future<void> delete(String id) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(id)
          .delete();

      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      // Error deleting task: $e
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final error = await context.read<AuthState>().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator:
                      (v) =>
                          v != null && v.contains('@')
                              ? null
                              : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (min 6 chars)',
                  ),
                  validator:
                      (v) =>
                          v != null && v.length >= 6
                              ? null
                              : 'Password too short',
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _submit, child: const Text('Login')),
                TextButton(
                  onPressed:
                      () => Navigator.pushNamed(context, SignUpScreen.route),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  static const route = '/signup';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final error = await context.read<AuthState>().signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _usernameCtrl.text.trim(),
      );
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator:
                      (v) =>
                          v != null && v.trim().length >= 3
                              ? null
                              : 'Username must be at least 3 characters',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator:
                      (v) =>
                          v != null && v.contains('@')
                              ? null
                              : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (min 6 chars)',
                  ),
                  validator:
                      (v) =>
                          v != null && v.length >= 6
                              ? null
                              : 'Password too short',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskHomeScreen extends StatelessWidget {
  const TaskHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Tasks'),
                if (auth.username != null)
                  Text(
                    'Welcome, ${auth.username}!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed:
                    () => Navigator.pushNamed(context, CalendarScreen.route),
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed:
                    () => Navigator.pushNamed(context, ProfileScreen.route),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthState>().logout(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed:
                () => Navigator.pushNamed(context, TaskEditorScreen.route),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: Consumer<TaskState>(
            builder: (context, state, _) {
              if (state.tasks.isEmpty) {
                return const Center(child: Text('No tasks yet. Tap + to add.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: state.tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = state.tasks[index];
                  final dateStr = DateFormat(
                    'EEE, MMM d • h:mm a',
                  ).format(t.dateTime);
                  return Dismissible(
                    key: ValueKey(t.id),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: const Text('Delete task?'),
                                  content: Text(
                                    'Are you sure you want to delete "${t.name}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) {
                      context.read<TaskState>().delete(t.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted "${t.name}"'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              TaskEditorScreen.route,
                              arguments: t,
                            ),
                        leading: Checkbox(
                          value: t.isCompleted,
                          onChanged: (bool? value) {
                            final willComplete = !t.isCompleted;
                            context.read<TaskState>().toggleTaskCompletion(
                              t.id,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  willComplete
                                      ? 'Marked "${t.name}" as completed'
                                      : 'Marked "${t.name}" as incomplete',
                                ),
                                backgroundColor:
                                    willComplete ? Colors.green : Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        title: Text(
                          t.name,
                          style: TextStyle(
                            decoration:
                                t.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                            color: t.isCompleted ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          [
                            dateStr,
                            if (t.description != null &&
                                t.description!.trim().isNotEmpty)
                              t.description!,
                          ].join('\n'),
                          style: TextStyle(
                            color: t.isCompleted ? Colors.grey : null,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Delete Task'),
                                        content: Text('Delete "${t.name}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true) {
                                  context.read<TaskState>().delete(t.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted "${t.name}"'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key});
  static const route = '/task-editor';

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dateTime;
  bool _isCompleted = false;
  late String _id;

  @override
  void initState() {
    super.initState();
    _id = const Uuid().v4();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = ModalRoute.of(context)?.settings.arguments;
    if (existing is TaskItem) {
      _id = existing.id;
      _nameCtrl.text = existing.name;
      _descCtrl.text = existing.description ?? '';
      _dateTime = existing.dateTime;
      _isCompleted = existing.isCompleted;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final current = _dateTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (timeOfDay == null) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final task = TaskItem(
        id: _id,
        name: _nameCtrl.text.trim(),
        dateTime: _dateTime ?? DateTime.now(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isCompleted: _isCompleted,
      );
      context.read<TaskState>().addOrUpdate(task);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        _dateTime == null
            ? 'Pick date & time'
            : DateFormat('EEE, MMM d, y • h:mm a').format(_dateTime!);

    return Scaffold(
      appBar: AppBar(title: const Text('Task Editor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Task name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v != null && v.trim().isNotEmpty
                            ? null
                            : 'Name is required',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.calendar_today),
                label: Text(dateLabel),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Mark as completed'),
                value: _isCompleted,
                onChanged: (bool? value) {
                  setState(() {
                    _isCompleted = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Calendar screen with task management
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  static const route = '/calendar';

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task Calendar'),
                if (auth.username != null)
                  Text(
                    'Welcome, ${auth.username}!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed:
                    () => Navigator.pushNamed(context, TaskEditorScreen.route),
              ),
            ],
          ),
          body: Consumer<TaskState>(
            builder: (context, taskState, _) {
              return Column(
                children: [
                  TableCalendar<TaskItem>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    eventLoader: (day) {
                      return taskState.tasks.where((task) {
                        return isSameDay(task.dateTime, day);
                      }).toList();
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: false,
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child:
                        _selectedDay == null
                            ? const Center(
                              child: Text('Select a day to view tasks'),
                            )
                            : _buildTaskList(taskState),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskList(TaskState taskState) {
    final tasksForDay =
        taskState.tasks.where((task) {
          return isSameDay(task.dateTime, _selectedDay!);
        }).toList();

    if (tasksForDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No tasks for ${DateFormat('MMM d, y').format(_selectedDay!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  () => Navigator.pushNamed(context, TaskEditorScreen.route),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tasksForDay.length,
      itemBuilder: (context, index) {
        final task = tasksForDay[index];
        final timeStr = DateFormat('h:mm a').format(task.dateTime);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap:
                () => Navigator.pushNamed(
                  context,
                  TaskEditorScreen.route,
                  arguments: task,
                ),
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (bool? value) {
                final willComplete = !task.isCompleted;
                taskState.toggleTaskCompletion(task.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      willComplete
                          ? 'Marked "${task.name}" as completed'
                          : 'Marked "${task.name}" as incomplete',
                    ),
                    backgroundColor:
                        willComplete ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            title: Text(
              task.name,
              style: TextStyle(
                decoration:
                    task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                color: task.isCompleted ? Colors.grey : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: task.isCompleted ? Colors.grey : null,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Text(
                    task.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: task.isCompleted ? Colors.grey : null,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Task'),
                        content: Text('Delete "${task.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  taskState.delete(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "${task.name}"'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}

// Profile/Settings screen for account management
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  static const route = '/profile';

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Profile & Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.person, color: Colors.grey),
                          title: const Text('Username'),
                          subtitle: Text(auth.username ?? 'Not set'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed:
                                () => _showEditUsernameDialog(context, auth),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.grey),
                          title: const Text('Email'),
                          subtitle: Text(auth.email ?? 'Not set'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.orange,
                          ),
                          title: const Text('Logout'),
                          subtitle: const Text('Sign out of your account'),
                          onTap: () {
                            auth.logout();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: const Text(
                            'Permanently delete your account and all data',
                          ),
                          onTap: () => _showDeleteAccountDialog(context, auth),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditUsernameDialog(BuildContext context, AuthState auth) {
    final TextEditingController usernameController = TextEditingController();
    usernameController.text = auth.username ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Username'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter new username',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Username must be at least 3 characters long',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  usernameController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final newUsername = usernameController.text.trim();
                  if (newUsername.length < 3) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Username must be at least 3 characters'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context); // Close dialog first

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Updating username...'),
                            ],
                          ),
                        ),
                  );

                  try {
                    final error = await auth.updateUsername(newUsername);
                    usernameController.dispose();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog

                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Username updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    usernameController.dispose();
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthState auth) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete your account?'),
                SizedBox(height: 8),
                Text(
                  '⚠️ This action cannot be undone. All your tasks and data will be permanently deleted.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context); // Close dialog first

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Deleting account...'),
                            ],
                          ),
                        ),
                  );

                  try {
                    final error = await auth.deleteAccount();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog

                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        // Account deleted successfully, navigate to login
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );
  }
}

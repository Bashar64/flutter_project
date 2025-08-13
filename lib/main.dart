import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const TaskApp());
}

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
          MapPickerScreen.route: (_) => const MapPickerScreen(),
        },
      ),
    );
  }
}

// Simple in-memory auth placeholder (front-end only; integrate Firebase later)
class AuthState extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  Future<void> login(String email, String password) async {
    // Placeholder validation
    if (email.isNotEmpty && password.length >= 6) {
      _email = email;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    await login(email, password);
  }

  void logout() {
    _isAuthenticated = false;
    _email = null;
    notifyListeners();
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
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final DateTime dateTime;
  final String? description;
  final String? locationLabel; // Optional label
  final double? latitude; // Optional lat
  final double? longitude; // Optional lng
}

class TaskState extends ChangeNotifier {
  final List<TaskItem> _tasks = <TaskItem>[];

  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  void addOrUpdate(TaskItem task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }
    notifyListeners();
  }

  void delete(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
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
      await context.read<AuthState>().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
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
      await context.read<AuthState>().signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, TaskEditorScreen.route),
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
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                      ) ??
                      false;
                },
                onDismissed: (_) => context.read<TaskState>().delete(t.id),
                child: ListTile(
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        TaskEditorScreen.route,
                        arguments: t,
                      ),
                  title: Text(t.name),
                  subtitle: Text(
                    [
                      dateStr,
                      if (t.description != null &&
                          t.description!.trim().isNotEmpty)
                        t.description!,
                      if (t.locationLabel != null) '📍 ${t.locationLabel}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
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
  String? _locationLabel;
  double? _lat;
  double? _lng;
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
      _locationLabel = existing.locationLabel;
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
        locationLabel: _locationLabel,
        latitude: _lat,
        longitude: _lng,
      );
      context.read<TaskState>().addOrUpdate(task);
      Navigator.pop(context);
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
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    MapPickerScreen.route,
                    arguments: MapPickerInput(
                      initialLatitude: _lat,
                      initialLongitude: _lng,
                      initialLabel: _locationLabel,
                    ),
                  );
                  if (result is MapPickerResult) {
                    setState(() {
                      _locationLabel = result.label;
                      _lat = result.latitude;
                      _lng = result.longitude;
                    });
                  }
                },
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  _locationLabel == null
                      ? 'Add location (Google Maps)'
                      : 'Location: $_locationLabel',
                ),
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

// Map picker input/result models
class MapPickerInput {
  const MapPickerInput({
    this.initialLatitude,
    this.initialLongitude,
    this.initialLabel,
  });
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLabel;
}

class MapPickerResult {
  const MapPickerResult({
    required this.latitude,
    required this.longitude,
    this.label,
  });
  final double latitude;
  final double longitude;
  final String? label;
}

// Basic Google Maps picker screen
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});
  static const route = '/map-picker';

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng? _selected;
  final TextEditingController _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _controller?.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    LatLng initial = const LatLng(25.276987, 55.296249); // Default: Dubai
    if (args is MapPickerInput) {
      if (args.initialLatitude != null && args.initialLongitude != null) {
        initial = LatLng(args.initialLatitude!, args.initialLongitude!);
        _selected ??= initial;
      }
      if (_labelCtrl.text.isEmpty && args.initialLabel != null) {
        _labelCtrl.text = args.initialLabel!;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          TextButton(
            onPressed:
                _selected == null
                    ? null
                    : () {
                      final res = MapPickerResult(
                        latitude: _selected!.latitude,
                        longitude: _selected!.longitude,
                        label:
                            _labelCtrl.text.trim().isEmpty
                                ? null
                                : _labelCtrl.text.trim(),
                      );
                      Navigator.pop(context, res);
                    },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 14),
              myLocationEnabled: false,
              onMapCreated: (c) => _controller = c,
              onTap: (pos) => setState(() => _selected = pos),
              markers: {
                if (_selected != null)
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: _selected!,
                  ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Location label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

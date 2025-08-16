import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import providers
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';

// Import screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/task_screens.dart';
import 'screens/other_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TaskApp());
}

class TaskApp extends StatelessWidget {
  TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: 'Task App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: LoginScreen(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/signup': (context) => SignUpScreen(),
          '/home': (context) => HomeScreen(),
          '/add': (context) => AddTaskScreen(),
          '/edit': (context) => EditTaskScreen(),
          '/calendar': (context) => CalendarScreen(),
          '/profile': (context) => ProfileScreen(),
        },
      ),
    );
  }
}


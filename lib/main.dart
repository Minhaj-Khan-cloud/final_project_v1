import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pages/auth_page.dart';
import 'pages/home_page.dart';

const _supabaseUrl = 'https://frfnpjlcnmuhitpftfgc.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyZm5wamxjbm11aGl0cGZ0ZmdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4MTEwNzIsImV4cCI6MjA5NTM4NzA3Mn0.rXkODahZQ6JpwKjw7UqM-AkRh3rHCe-dgekmsOZ7Eqc';

final supabase = Supabase.instance.client;

const kPrimary = Color(0xFF0066CC);
const kSecondary = Color(0xFF00CC99);
const kBg = Color(0xFFF5F7FA);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> schedulePlanNotification({
  required int id,
  required String title,
  required DateTime scheduledTime,
}) async {
  if (kIsWeb) return;
  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'LU-Collab Planner',
      title,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_channel',
          'Planner Alerts',
          channelDescription: 'Reminders for your upcoming academic plans',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (_) {}
}

Future<void> cancelPlanNotification(int id) async {
  if (kIsWeb) return;
  try {
    await flutterLocalNotificationsPlugin.cancel(id);
  } catch (_) {}
}

const Map<String, List<String>> kCoursesByYear = {
  'Year 1': [
    'CSE-1101 Introduction to Computing',
    'CSE-1151 Discrete Mathematics',
    'MAT-1151 Calculus and Linear Algebra',
    'GED-1131 Basic English',
    'GED-1145 Bangladesh Studies',
    'CSE-1211 Structured Programming',
    'MAT-1251 Differential Equation, Laplace & Fourier',
    'GED-1171 Physics: Heat, Light and Sound',
    'EEE-1221 Electrical Circuits',
    'GED-1231 Functional English',
    'GED-1201 Introduction to Sociology',
  ],
  'Year 2': [
    'CSE-2111 Data Structures',
    'CSE-2112 Data Structures Sessional',
    'EEE-2121 Electronic Devices and Circuits',
    'MAT-2151 Coordinate Geometry & Vector Analysis',
    'GED-2181 Introduction to Economics',
    'GED-2192 Statistics',
    'GED-1161 Chemistry',
    'PHY-2171 Electromagnetism and Modern Physics',
    'CSE-2211 Computer Algorithms and Complexity',
    'CSE-2201 Theory of Computation',
    'CSE-2231 Data Communications',
    'CSE-2221 Digital Logic Design',
    'CSE-2222 Digital Logic Design Sessional',
    'MAT-2251 Complex Variable and Probability',
  ],
  'Year 3': [
    'CSE-3111 Object Oriented Programming',
    'CSE-3121 Computer Architecture and Design',
    'CSE-3113 Database Management System',
    'CSE-3115 Numerical Methods',
    'CSE-3212 Smartphone Application Development',
    'CSE-3213 Software Engineering',
    'CSE-3214 Software Engineering Sessional',
    'CSE-3231 Computer Networks',
    'CSE-3232 Computer Networks Sessional',
    'CSE-3201 Microprocessor and Assembly Language',
    'CSE-3202 Microprocessor and Assembly Language Sessional',
    'GED-1116 Introduction to Management',
  ],
  'Year 4': [
    'CSE-4111 Artificial Intelligence',
    'CSE-4112 Artificial Intelligence Sessional',
    'CSE-4113 Compiler Design and Construction',
    'CSE-4114 Compiler Design and Construction Sessional',
    'CSE-4116 Web Technologies',
    'CSE-4211 Operating System',
    'CSE-4267 Machine Learning',
    'CSE-4161 Computer and Cyber Security',
    'CSE-4135 Cloud Computing',
    'CSE-4163 Internet of Things',
    'CSE-4165 Neural Network and Fuzzy Logic',
    'CSE-4167 Human Computer Interaction',
  ],
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  runApp(const LUCollabApp());
}

class LUCollabApp extends StatelessWidget {
  const LUCollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LU-Collab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: kPrimary, secondary: kSecondary),
        scaffoldBackgroundColor: kBg,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Colors.white,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data?.session != null
            ? const HomePage()
            : const AuthPage();
      },
    );
  }
}

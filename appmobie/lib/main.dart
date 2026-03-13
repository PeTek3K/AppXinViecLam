import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode'); // 'dark' | 'light' | 'system'
  themeModeNotifier.value = switch (saved) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };
  themeModeNotifier.addListener(() {
    final m = themeModeNotifier.value;
    prefs.setString(
      'themeMode',
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.light
          ? 'light'
          : 'system',
    );
  });
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());

  // Start background notification listener (shows in-app SnackBars for new notifications)
  // This uses a Firestore listener and requires Firebase initialized above.
  try {
    // lazy import of service
    // ignore: unnecessary_non_null_assertion
    notificationService.start();
  } catch (_) {}
}

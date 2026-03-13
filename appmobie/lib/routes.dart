import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin/admin_home.dart';
import 'screens/create_cv_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/ResetPassword_Screen.dart';
import 'screens/my_cvs_screen.dart';
import 'admin/admin_cvs_page.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const admin = '/admin';
  static const createCv = '/create-cv';
  static const myCvs = '/my-cvs';
  static const adminCvs = '/admin-cvs';
static const QuickAction = '/quick-action';
  static Map<String, WidgetBuilder> get map {
    final m = <String, WidgetBuilder>{
      splash: (_) => const SplashScreen(),
      login: (_) => const LoginScreen(),
      register: (_) => const RegisterScreen(),
      resetPassword: (_) => const ResetPassword_Screen(),
      home: (_) => const MainScreen(),
    };
    // Register admin route only on non-web platforms
    if (!kIsWeb) {
      m[admin] = (_) => const AdminHome();
    }
    // Create CV screen
    m[createCv] = (_) => const CreateCvScreen();
    m[myCvs] = (_) => const MyCvsScreen();
    if (!kIsWeb) m[adminCvs] = (_) => const AdminCvsPage();
    return m;
  }
}

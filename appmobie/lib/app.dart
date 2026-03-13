import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'routes.dart';
import 'screens/login_screen.dart';

// 👉 đặt global ở đây để nơi khác có thể đổi theme
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

// Global navigator key so services can show UI (SnackBar) from background listeners
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final light = buildLightTheme();
        final dark = buildDarkTheme();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: 'Auth Starter',
          theme: light.copyWith(
            textTheme: GoogleFonts.interTextTheme(light.textTheme),
          ),
          darkTheme: dark.copyWith(
            textTheme: GoogleFonts.interTextTheme(dark.textTheme),
          ),
          themeMode: mode,
          routes: Routes.map,
          // nếu muốn route mặc định kiểm tra auth -> làm RootScreen trong routes
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (_) => const LoginScreen()),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
        );
      },
    );
  }
}

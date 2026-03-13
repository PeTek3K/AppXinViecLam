import 'package:flutter/material.dart';

ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.blueAccent,
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 1),
  scaffoldBackgroundColor: const Color(0xFFF7F7F7),
);

ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.blueAccent,
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
);

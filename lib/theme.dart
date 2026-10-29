import 'package:flutter/material.dart';

const navy = Color(0xFF071526);
const navBar = Color(0xFF0A1D30);
const panel = Color(0xFF10263C);
const panel2 = Color(0xFF153B5C);
const blue = Color(0xFF39A9FF);
const amber = Color(0xFFFFC857);
const red = Color(0xFFFF5D52);
const green = Color(0xFF55D68B);
const purple = Color(0xFFB57BFF);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark);
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy,
    colorScheme: scheme.copyWith(surface: navy),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(backgroundColor: navy, elevation: 0, centerTitle: false),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: panel),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Colour for a 0..2 severity (0 = normal, 1 = watch, 2 = warning).
Color levelColor(int level) => switch (level) { 2 => red, 1 => amber, _ => green };

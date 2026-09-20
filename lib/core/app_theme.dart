import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF243447);
  static const blue = Color(0xFF3498DB);
  static const deepBlue = Color(0xFF2980B9);
  static const background = Color(0xFFF4F7FB);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: const Color(0xFFF39C12),
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE7EDF4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE4EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE4EC)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// App-wide styling, color palette, and Material 3 theme configuration
class AppTheme {
  static const Color background = Color(0xFF0F0F13);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceLight = Color(0xFF22223A);
  static const Color border = Color(0xFF2A2A3E);
  static const Color accent = Color(0xFF6C63FF);
  static const Color terminalBg = Color(0xFF0A0A10);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorSchemeSeed: accent,
      useMaterial3: true,
      cardTheme: const CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

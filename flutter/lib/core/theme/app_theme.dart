import 'package:flutter/material.dart';

/// App-wide styling, color palette, and bespoke dark design system.
/// Crafted with a high-end obsidian & vitality aesthetic (comparable to Garmin & Nothing OS).
class AppTheme {
  // Base Canvas & Surfaces
  static const Color background = Color(0xFF0A0C10);
  static const Color surface = Color(0xFF131720);
  static const Color surfaceLight = Color(0xFF1B212D);
  static const Color surfaceElevated = Color(0xFF222B3A);
  static const Color border = Color(0xFF202736);
  static const Color borderSubtle = Color(0xFF19202D);
  static const Color terminalBg = Color(0xFF07090C);

  // Vitality & Accent Colors
  static const Color accent = Color(0xFF00E5FF); // Electric Cyan
  static const Color accentDim = Color(0xFF00B4D8);
  static const Color heartRate = Color(0xFFFF4B72); // Crimson Coral
  static const Color steps = Color(0xFF00E5FF); // Electric Cyan
  static const Color calories = Color(0xFFFF8A00); // Warm Ember Orange
  static const Color sleep = Color(0xFF818CF8); // Soft Lavender
  static const Color spo2 = Color(0xFF38BDF8); // Sky Blue
  static const Color bloodPressure = Color(0xFFF43F5E); // Rose
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Typographic Hierarchy Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentDim,
        surface: surface,
        error: heartRate,
        onPrimary: Color(0xFF0A0C10),
        onSurface: textPrimary,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF0A0C10),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0A0C10);
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return surfaceLight;
        }),
        trackOutlineColor: WidgetStateProperty.all(border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 24,
      ),
    );
  }
}

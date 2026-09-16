import 'package:flutter/material.dart';

/// The ride experience deliberately uses neutral tones, including feedback.
abstract final class RideTheme {
  static const background = Color(0xFF252930);
  static const panel = Color(0xFF17191D);
  static const field = Color(0xFF202327);
  static const border = Color(0xFF454A52);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFFB2B7C0);

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: text,
      onPrimary: panel,
      primaryContainer: field,
      onPrimaryContainer: text,
      secondary: muted,
      onSecondary: panel,
      secondaryContainer: background,
      onSecondaryContainer: text,
      tertiary: text,
      onTertiary: panel,
      surface: panel,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: border,
      error: text,
      onError: panel,
      errorContainer: field,
      onErrorContainer: text,
      surfaceTint: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: text, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        disabledBackgroundColor: const Color(0xFF33373D),
        disabledForegroundColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
  );
}

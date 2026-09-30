import 'package:flutter/material.dart';

const _radius = 12.0;

/// Dark theme for the whole app. Screens take color, shape, and controls from here.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F4E79),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF3B82F6),
    onPrimary: Colors.white,
    surface: const Color(0xFF121418),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_radius),
    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: shape,
      ),
    ),
  );
}

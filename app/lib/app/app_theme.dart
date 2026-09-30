import 'package:flutter/material.dart';

const _radius = 12.0;

/// Dark theme for the whole app. Screens take color, shape, and controls from here.
ThemeData appTheme() {
  const canvas = Color(0xFF10151C);
  const panel = Color(0xFF1A2332);
  const line = Color(0xFF2C3A50);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F4E79),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF3B82F6),
    onPrimary: Colors.white,
    surface: canvas,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );
  final panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: line),
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_radius),
    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(bottom: BorderSide(color: line)),
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: panelShape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF171C26),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF171C26),
      indicatorColor: const Color(0xFF3B82F6).withValues(alpha: 0.24),
    ),
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

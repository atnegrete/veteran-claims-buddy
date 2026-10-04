import 'package:flutter/material.dart';

/// Dark palette. One blue family for the product, one red family for danger.
abstract final class AppColors {
  static const navy = Color(0xFF1F4E79);
  static const blue = Color(0xFF3B82F6);
  static const canvas = Color(0xFF10151C);
  static const rail = Color(0xFF171C26);
  static const card = Color(0xFF1A2332);
  static const line = Color(0xFF2C3A50);
  static const text = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFF94A3B8);
  static const dangerFill = Color(0xFFB91C1C);
  static const dangerText = Color(0xFFF87171);
}

const _radius = 12.0;

/// Text button that opens a dangerous step or removes one item.
///
/// Red fill, white label. The letters are not red.
ButtonStyle dangerTextStyle() {
  return TextButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: AppColors.dangerFill,
  );
}

/// Filled button that adds one row to a list. Navy fill, white label.
///
/// The gray outline stays on Back, Close, and Cancel.
ButtonStyle secondaryFilledStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.38),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
  );
}

/// Filled button that commits a destructive action.
ButtonStyle dangerFilledStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.dangerFill,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.dangerFill.withValues(alpha: 0.38),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
  );
}

/// Dark theme for the whole app. Screens take color, shape, and controls from here.
ThemeData appTheme() {
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(_radius)),
  );
  const panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    side: BorderSide(color: AppColors.line),
  );
  const outline = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(_radius)),
    borderSide: BorderSide(color: AppColors.line),
  );
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.blue,
        onPrimary: Colors.white,
        secondary: AppColors.navy,
        onSecondary: Colors.white,
        surface: AppColors.canvas,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textMuted,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
        error: AppColors.dangerText,
        onError: Colors.white,
        errorContainer: AppColors.dangerFill,
        onErrorContainer: Colors.white,
        surfaceContainerLow: AppColors.card,
        surfaceContainer: AppColors.card,
        surfaceContainerHigh: AppColors.card,
        surfaceContainerHighest: AppColors.line,
        primaryContainer: AppColors.blue.withValues(alpha: 0.24),
        onPrimaryContainer: AppColors.text,
        surfaceTint: AppColors.canvas,
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.text),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: panelShape,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      shape: panelShape,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.card,
      shape: shape,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.text,
      iconColor: AppColors.textMuted,
      subtitleTextStyle: TextStyle(color: AppColors.textMuted),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.rail,
      labelType: NavigationRailLabelType.all,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.rail,
      indicatorColor: AppColors.blue.withValues(alpha: 0.24),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.line.withValues(alpha: 0.35),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      helperStyle: const TextStyle(color: AppColors.textMuted),
      errorStyle: const TextStyle(color: AppColors.dangerText),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
      errorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.dangerText),
      ),
      focusedErrorBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.dangerText, width: 1.5),
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
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size.fromHeight(48),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

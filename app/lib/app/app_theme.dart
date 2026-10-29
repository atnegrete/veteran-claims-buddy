import 'package:flutter/material.dart';

import 'app_scroll.dart';

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
  static const sand = Color(0xFFE8C39E);
  static const dangerFill = Color(0xFFB91C1C);
  static const dangerText = Color(0xFFF87171);

  /// Finished-part fill. White label and white check. Dark enough that the
  /// words stay readable. Not the calculator's money green.
  static const success = Color(0xFF047857);

  /// Money green. The estimated dollar amount on the calculator, and the
  /// success edge on an InfoNote. Not the finished-part fill.
  static const money = Color(0xFF34D399);
}

const _radius = 12.0;

/// Display face. Headlines, section titles, card titles, prices.
const _display = 'Fraunces';

/// UI and body face. Everything that is not a display headline.
const _ui = 'Source Sans 3';

/// A Fraunces display style. Weight drives the variable font's weight axis,
/// so `copyWith(fontWeight:)` keeps working on screens.
TextStyle _displayStyle({
  required double size,
  FontWeight weight = FontWeight.w600,
  double height = 1.1,
  double letterSpacing = -0.4,
}) {
  return TextStyle(
    fontFamily: _display,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: weight,
  );
}

/// A Source Sans 3 UI or body style.
TextStyle _uiStyle({
  required double size,
  FontWeight weight = FontWeight.w400,
  double height = 1.45,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: _ui,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: weight,
  );
}

/// Sand, uppercase, tracked label that sits above a title.
TextStyle eyebrowStyle() {
  return _uiStyle(
    size: 12,
    weight: FontWeight.w600,
    letterSpacing: 1.6,
  ).copyWith(color: AppColors.sand);
}

/// A link inside a paragraph. Sand and underlined.
TextStyle sandLinkStyle() {
  return _uiStyle(size: 15.5, weight: FontWeight.w600).copyWith(
    color: AppColors.sand,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.sand,
  );
}

TextTheme _buildTextTheme() {
  final theme = TextTheme(
    displayLarge: _displayStyle(size: 44, height: 1.04),
    displayMedium: _displayStyle(size: 36, height: 1.06),
    displaySmall: _displayStyle(size: 30, height: 1.08),
    headlineLarge: _displayStyle(size: 29, height: 1.1),
    headlineMedium: _displayStyle(size: 25, height: 1.12),
    headlineSmall: _displayStyle(size: 22, height: 1.15),
    titleLarge: _displayStyle(size: 20, height: 1.2),
    titleMedium: _displayStyle(size: 17, height: 1.3, letterSpacing: -0.2),
    titleSmall: _uiStyle(size: 14, weight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: _uiStyle(size: 17, height: 1.55),
    bodyMedium: _uiStyle(size: 15.5, height: 1.5),
    bodySmall: _uiStyle(size: 13.5, height: 1.45),
    labelLarge: _uiStyle(size: 15, weight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: _uiStyle(
      size: 13,
      weight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelSmall: _uiStyle(size: 11, weight: FontWeight.w600, letterSpacing: 0.4),
  );
  return theme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
}

/// Weight-600 label for buttons and other controls.
const _buttonTextStyle = TextStyle(
  fontFamily: _ui,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
);

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
    fontFamily: _ui,
    textTheme: _buildTextTheme(),
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.text),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _displayStyle(
        size: 19,
        height: 1.1,
      ).copyWith(color: AppColors.text),
      shape: const Border(bottom: BorderSide(color: AppColors.line)),
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
        textStyle: _buttonTextStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size.fromHeight(48),
        shape: shape,
        textStyle: _buttonTextStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        textStyle: _buttonTextStyle,
      ),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(scrollbarThumbThickness),
      crossAxisMargin: scrollbarCrossAxisMargin,
      radius: Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(AppColors.textMuted),
      interactive: true,
    ),
  );
}

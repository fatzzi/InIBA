import 'package:flutter/material.dart';

/// App theme matching the Figma wireframes: white screens, near-black text and outlines, grey placeholders,
/// centred bold titles and rounded outlined buttons.
abstract final class AppColors {
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF5C5C5C);
  static const line = Color(0xFF9E9E9E);
  static const placeholder = Color(0xFFE6E6E6);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.ink).copyWith(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    primaryContainer: AppColors.placeholder,
    onPrimaryContainer: AppColors.muted,
    secondaryContainer: AppColors.placeholder,
    onSecondaryContainer: AppColors.ink,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.placeholder,
    outline: AppColors.ink,
    outlineVariant: AppColors.line,
    surfaceTint: Colors.transparent,
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        shape: buttonShape,
        minimumSize: const Size(0, 48),
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        shape: buttonShape,
        minimumSize: const Size(0, 48),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.ink, textStyle: const TextStyle(fontSize: 15)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

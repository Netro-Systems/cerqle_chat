import 'package:flutter/material.dart';

const cerqlePrimary = Color(0xFF3E2A49);
const cerqlePrimarySoft = Color(0xFFF1E8F5);
const cerqleSecondary = Color(0xFF8F5FA7);
const cerqleBackground = Color(0xFFF8FAFC);
const cerqleBackgroundAlt = Color(0xFFF1F5F9);
const cerqleSurface = Color(0xFFFFFFFF);
const cerqleSurfaceMuted = Color(0xFFE2E8F0);
const cerqleBorder = Color(0xFFCBD5E1);
const cerqleTextPrimary = Color(0xFF0F172A);
const cerqleTextSecondary = Color(0xFF475569);
const cerqleTextMuted = Color(0xFF64748B);

ThemeData buildExampleTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: cerqlePrimary,
  ).copyWith(
    primary: cerqlePrimary,
    secondary: cerqleSecondary,
    onPrimary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: cerqleBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: cerqleSurface,
      foregroundColor: cerqleTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cerqlePrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cerqlePrimary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: cerqlePrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    useMaterial3: true,
  );
}

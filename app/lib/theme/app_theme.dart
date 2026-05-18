import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Style colors from DESIGN.md
  static const Color primary = Color(0xFF000666); // Dark Navy
  static const Color primaryLight = Color(0xFFE0E0FF); // Primary Fixed
  static const Color userBubble = Color(0xFFFFE082); // Action Yellow
  static const Color agentBubble = Color(0xFFD4EDDA); // Light Green
  static const Color background = Color(0xFFFBF8FF); // Surface Lavender
  static const Color textDark = Color(0xFF1B1B21); // On Surface
  static const Color textGrey = Color(0xFF454652); // On Surface Variant
  static const Color inputBg = Color(0xFFFFFFFF); // Surface Container Lowest

  // Extended color tokens from DESIGN.md
  static const Color primaryContainer = Color(0xFF1A237E);
  static const Color onPrimaryContainer = Color(0xFF8690EE);
  static const Color secondary = Color(0xFF006C4E); // Growth Green
  static const Color secondaryContainer = Color(0xFF83F5C6);
  static const Color tertiaryContainer = Color(0xFF492800); // Action Orange
  static const Color onTertiaryContainer = Color(0xFFDC8200);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color outlineVariant = Color(0xFFC6C5D4);
  static const Color surfaceContainerLow = Color(0xFFF5F2FB);

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        fontFamily: 'Roboto',
      );
}

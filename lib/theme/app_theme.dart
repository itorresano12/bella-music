// lib/theme/app_theme.dart
// Premium Dark Mode palette — #0D0D0D base, violet-to-neon-blue gradients.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Colour Tokens ────────────────────────────────────────────────────────
  static const Color background    = Color(0xFF0D0D0D);
  static const Color surface       = Color(0xFF1A1A1A);
  static const Color surfaceLight  = Color(0xFF242424);
  static const Color onSurface     = Color(0xFFF0F0F0);
  static const Color onSurfaceSub  = Color(0xFF8A8A8A);

  // Accent gradient: violet → neon-blue
  static const Color accentViolet  = Color(0xFF8B5CF6);  // electric violet
  static const Color accentBlue    = Color(0xFF06B6D4);  // neon cyan-blue
  static const Color accentPink    = Color(0xFFEC4899);  // highlight

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentViolet, accentBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D0D0D), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Text Theme ───────────────────────────────────────────────────────────
  static TextTheme get _textTheme => GoogleFonts.montserratTextTheme(
    const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface),
      titleLarge:    TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
      bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: onSurfaceSub),
      labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.5),
    ),
  );

  // ─── Full Dark Theme ──────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary:   accentViolet,
      secondary: accentBlue,
      surface:   surface,
      onSurface: onSurface,
      error:     Color(0xFFEF4444),
    ),
    textTheme: _textTheme,
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: onSurface),
      iconTheme: const IconThemeData(color: onSurface),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accentViolet,
      unselectedItemColor: onSurfaceSub,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accentViolet,
      inactiveTrackColor: surfaceLight,
      thumbColor: accentViolet,
      overlayColor: accentViolet.withOpacity(0.2),
    ),
    dividerColor: surfaceLight,
    iconTheme: const IconThemeData(color: onSurface, size: 24),
  );
}

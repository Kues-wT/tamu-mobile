import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TAMU design system.
/// Colours and sizes come straight from the Figma prototype spec.
class TamuColors {
  static const primary = Color(0xFF2E7D32); // Forest Green
  static const secondary = Color(0xFF81C784); // Leaf Green
  static const lightGreen = Color(0xFFE8F5E9); // Tint
  static const darkGreen = Color(0xFF1A2E1A); // Hero background
  static const background = Color(0xFFF5F5F5); // Off-white
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF616161);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFFF9A825);
  static const info = Color(0xFF1565C0);
  static const border = Color(0xFFE0E0E0);
}

/// Spacing + sizing rules (accessibility for older rural users).
class TamuSizes {
  static const pagePadding = 16.0;
  static const cardPadding = 16.0;
  static const cardRadius = 12.0;
  static const buttonRadius = 8.0;
  static const buttonHeight = 48.0;
  static const inputHeight = 48.0;
  static const gap = 12.0;
  static const bottomNavHeight = 64.0;
}

ThemeData buildTamuTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TamuColors.primary,
      primary: TamuColors.primary,
      secondary: TamuColors.secondary,
      error: TamuColors.danger,
      surface: TamuColors.surface,
    ),
    scaffoldBackgroundColor: TamuColors.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.bold, color: TamuColors.textPrimary),
      headlineMedium: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w600, color: TamuColors.textPrimary),
      titleMedium: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: TamuColors.textPrimary),
      // Body is 16 MINIMUM - required for older users.
      bodyLarge: GoogleFonts.poppins(fontSize: 16, color: TamuColors.textPrimary),
      bodyMedium: GoogleFonts.poppins(fontSize: 16, color: TamuColors.textPrimary),
      bodySmall: GoogleFonts.poppins(fontSize: 14, color: TamuColors.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TamuColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TamuColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(TamuSizes.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        ),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: TamuColors.surface,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.primary, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(fontSize: 14, color: TamuColors.textSecondary),
    ),
  );
}

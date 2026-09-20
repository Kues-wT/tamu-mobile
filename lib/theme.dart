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
  static const hint = Color(0xFF9E9E9E);
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
  // Every colour is pinned explicitly so Material 3 never auto-generates
  // a low-contrast pair (e.g. white text on a white surface).
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: TamuColors.primary,
    onPrimary: Colors.white,
    primaryContainer: TamuColors.lightGreen,
    onPrimaryContainer: TamuColors.textPrimary,
    secondary: TamuColors.secondary,
    onSecondary: TamuColors.textPrimary,
    secondaryContainer: TamuColors.lightGreen,
    onSecondaryContainer: TamuColors.textPrimary,
    error: TamuColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: TamuColors.danger,
    surface: Colors.white,
    onSurface: TamuColors.textPrimary,
    surfaceContainerHighest: Color(0xFFEEEEEE),
    onSurfaceVariant: TamuColors.textSecondary,
    outline: TamuColors.border,
    outlineVariant: TamuColors.border,
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: TamuColors.textPrimary,
    onInverseSurface: Colors.white,
    inversePrimary: TamuColors.secondary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TamuColors.background,
  );

  final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
    // Force readable defaults everywhere.
    bodyColor: TamuColors.textPrimary,
    displayColor: TamuColors.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
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
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TamuColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFBDBDBD),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(TamuSizes.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        ),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TamuColors.primary,
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TamuColors.primary,
        minimumSize: const Size.fromHeight(TamuSizes.buttonHeight),
        side: const BorderSide(color: TamuColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        ),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    iconTheme: const IconThemeData(color: TamuColors.textSecondary),

    cardTheme: CardThemeData(
      color: TamuColors.surface,
      surfaceTintColor: Colors.transparent, // stops M3 tinting cards green
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      ),
    ),

    // Inputs: white box, dark text, grey hint. Never white-on-white.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: GoogleFonts.poppins(fontSize: 16, color: TamuColors.hint),
      labelStyle: GoogleFonts.poppins(fontSize: 14, color: TamuColors.textSecondary),
      floatingLabelStyle:
          GoogleFonts.poppins(fontSize: 14, color: TamuColors.primary),
      helperStyle: GoogleFonts.poppins(fontSize: 13, color: TamuColors.textSecondary),
      errorStyle: GoogleFonts.poppins(fontSize: 13, color: TamuColors.danger),
      prefixIconColor: TamuColors.textSecondary,
      suffixIconColor: TamuColors.textSecondary,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
        borderSide: const BorderSide(color: TamuColors.border),
      ),
    ),

    // Dropdown popup: white background, dark text.
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: GoogleFonts.poppins(fontSize: 16, color: TamuColors.textPrimary),
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      textStyle: GoogleFonts.poppins(fontSize: 16, color: TamuColors.textPrimary),
    ),

    // Dialogs: white background, dark title and body.
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: TamuColors.textPrimary),
      contentTextStyle:
          GoogleFonts.poppins(fontSize: 16, color: TamuColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      ),
    ),

    // Snackbars: dark background, white text - always readable.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TamuColors.textPrimary,
      contentTextStyle: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
      actionTextColor: TamuColors.secondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TamuSizes.buttonRadius),
      ),
    ),

    // Chips: dark text on light fill by default.
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: TamuColors.lightGreen,
      surfaceTintColor: Colors.transparent,
      labelStyle: GoogleFonts.poppins(fontSize: 14, color: TamuColors.textPrimary),
      secondaryLabelStyle:
          GoogleFonts.poppins(fontSize: 14, color: TamuColors.primary),
      side: const BorderSide(color: TamuColors.border),
      shape: const StadiumBorder(),
    ),

    listTileTheme: const ListTileThemeData(
      textColor: TamuColors.textPrimary,
      iconColor: TamuColors.textSecondary,
    ),

    dividerTheme: const DividerThemeData(color: TamuColors.border, thickness: 1),

    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: TamuColors.primary),
  );
}

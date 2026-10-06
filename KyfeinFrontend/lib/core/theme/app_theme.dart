import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1B4332); // Deep Forest Green
  static const Color secondaryColor = Color(0xFFD4A373); // Warm Wood
  static const Color accentColor = Color(0xFFDDA15E); // Light Wood Gold
  static const Color backgroundColor = Color(0xFFE9F5E6); // Light Sage Cream
  static const Color surfaceColor = Colors.white;
  static const Color darkBackground = Color(0xFF0F241A); // Dark Greenish Black

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: GoogleFonts.outfitTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: primaryColor.withOpacity(0.15),
      side: BorderSide(color: Colors.grey.shade200),
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade100,
      thickness: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: secondaryColor,
      secondary: primaryColor,
      surface: Color(0xFF2A2622),
    ),
    textTheme: GoogleFonts.outfitTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF2A2622),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

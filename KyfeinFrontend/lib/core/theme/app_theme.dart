import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6F4E37); // Warm Coffee
  static const Color secondaryColor = Color(0xFFC0A080); // Latte Gold
  static const Color accentColor = Color(0xFFE27D60); // Warm Coral
  static const Color backgroundColor = Color(0xFFF9F6F0); // Off-white cream
  static const Color surfaceColor = Colors.white;
  static const Color darkBackground = Color(0xFF1E1B18); // Dark Roasted Coffee

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2A2622),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

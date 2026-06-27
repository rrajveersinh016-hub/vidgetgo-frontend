import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.neonPurple,
      scaffoldBackgroundColor: AppColors.background,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonPurple,
        secondary: AppColors.neonPurpleGlow,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
        ),
        bodySmall: GoogleFonts.dmSans(
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
        ),
        labelSmall: GoogleFonts.dmSans(
          color: AppColors.textSecondary,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.orbitron(
          color: AppColors.neonPurple,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.neonPurple,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonPurple,
          foregroundColor: AppColors.textPrimary,
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: AppColors.neonPurpleGlow,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMid,
        hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neonPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

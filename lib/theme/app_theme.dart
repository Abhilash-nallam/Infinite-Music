import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for Infinite Music.
/// Keep every color/spacing decision here so screens never hardcode values.
class AppColors {
  static const bg = Color(0xFF0B0B14);
  static const bgElevated = Color(0xFF14131F);
  static const card = Color(0xFF17151F);
  static const violet = Color(0xFF7C3AED);
  static const violetSoft = Color(0xFFA78BFA);
  static const amber = Color(0xFFF5A623);
  static const text = Color(0xFFF2F0F7);
  static const muted = Color(0xFF8B8798);
  static const divider = Color(0x0DFFFFFF); // 5% white
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.violet,
        secondary: AppColors.amber,
        surface: AppColors.bgElevated,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.text,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.violetSoft,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.bg,
        indicatorColor: Color(0x337C3AED),
        labelTextStyle: MaterialStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: AppColors.divider,
    );
  }

  static const cardRadius = 16.0;
  static const artRadius = 24.0;
}

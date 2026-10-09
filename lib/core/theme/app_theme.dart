import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const Color ink = Color(0xFF252531);
  static const Color muted = Color(0xFF85879F);
  static const Color border = Color(0xFFE6E6E3);
  static const Color error = Color(0xFFC72C21);
  static const Color success = Color(0xFF4B9460);
  static const Color accent = Color(0xFF6D5FE0);
  static const Color subtleSurface = Color(0xFFF8F8F7);
  static const Color quietSurface = Color(0xFFFBFBFA);
  static const Color badgeSurface = Color(0xFFF5F5F3);
  static const Color skeleton = Color(0xFFEDEDEA);
  static const Color skeletonTrack = Color(0xFFF4F4F2);
}

abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x66000000),
        dragHandleColor: Color(0xFF4A4A55),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

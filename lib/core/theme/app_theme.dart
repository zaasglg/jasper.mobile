import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B5FEF),
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
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

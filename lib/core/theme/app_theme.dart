import 'app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'app_input_theme.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const Color canvas = Color(0xFFFFFFFF);
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
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color chatCanvas = Color(0xFFF3F4F7);
  static const Color outgoingMessage = Color(0xFFF0ECFF);
  static const Color quoteSurface = Color(0xFFF7F7FA);
}

abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      iconTheme: const IconThemeData(size: AppIconSizes.standard),
      inputDecorationTheme: AppInputTheme.light,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        surface: AppColors.canvas,
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        showCloseIcon: true,
        closeIconColor: AppColors.muted,
        actionTextColor: AppColors.accent,
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFFA0A3B3), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFE8E9EF);
          }
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFFDFE1E9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        selectedTileColor: Color(0xFFF1EFFF),
        selectedColor: AppColors.accent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x66000000),
        dragHandleColor: Color(0xFFD6D8E1),
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

import 'app_icon_sizes.dart';
import '../widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'app_input_theme.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static AppPalette of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.dark);
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

class AppPalette {
  const AppPalette(this.dark);
  final bool dark;
  Color get canvas => dark ? const Color(0xFF18191F) : AppColors.canvas;
  Color get ink => dark ? const Color(0xFFF0F0F5) : AppColors.ink;
  Color get muted => dark ? const Color(0xFFA4A6BA) : AppColors.muted;
  Color get border => dark ? const Color(0xFF363842) : AppColors.border;
  Color get error => dark ? const Color(0xFFFF8A80) : AppColors.error;
  Color get success => dark ? const Color(0xFF81C995) : AppColors.success;
  Color get accent => dark ? const Color(0xFFB3A7FF) : AppColors.accent;
  Color get subtleSurface =>
      dark ? const Color(0xFF22232B) : AppColors.subtleSurface;
  Color get quietSurface =>
      dark ? const Color(0xFF1D1E25) : AppColors.quietSurface;
  Color get badgeSurface =>
      dark ? const Color(0xFF2B2D37) : AppColors.badgeSurface;
  Color get skeleton => dark ? const Color(0xFF363842) : AppColors.skeleton;
  Color get skeletonTrack =>
      dark ? const Color(0xFF292B34) : AppColors.skeletonTrack;
  Color get onAccent => dark ? const Color(0xFF241B50) : AppColors.onAccent;
  Color get chatCanvas => dark ? const Color(0xFF121318) : AppColors.chatCanvas;
  Color get outgoingMessage =>
      dark ? const Color(0xFF38304F) : AppColors.outgoingMessage;
  Color get quoteSurface =>
      dark ? const Color(0xFF292A35) : AppColors.quoteSurface;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = AppPalette(brightness == Brightness.dark);
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      iconTheme: IconThemeData(size: AppIconSizes.standard, color: colors.ink),
      inputDecorationTheme: AppInputTheme.light.copyWith(
        fillColor: colors.subtleSurface,
        hintStyle: TextStyle(color: colors.muted),
      ),
      dividerColor: colors.border,
      brightness: brightness,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        surface: colors.canvas,
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.canvas,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        showCloseIcon: true,
        closeIconColor: colors.muted,
        actionTextColor: colors.accent,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFFA0A3B3), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.skeleton;
          }
          if (states.contains(WidgetState.selected)) return colors.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.canvas),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.canvas,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.canvas,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFFDFE1E9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: colors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        selectedTileColor: colors.outgoingMessage,
        selectedColor: colors.accent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.canvas,
        modalBackgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x66000000),
        dragHandleColor: Color(0xFFD6D8E1),
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.canvas,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        iconTheme: IconThemeData(
          color: colors.ink,
          size: AppBackButton.iconSize,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(AppBackButton.icon, size: AppBackButton.iconSize),
      ),
    );
  }
}

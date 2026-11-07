import 'package:flutter/material.dart';

/// Quiet, consistent input states across forms and dialogs.
abstract final class AppInputTheme {
  static InputDecorationTheme get light {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F8F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF6D5FE0)),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFC72C21)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFC72C21)),
      ),
    );
  }
}

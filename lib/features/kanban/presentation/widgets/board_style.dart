import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Surface roles and geometry for the project board.
abstract final class BoardStyle {
  static const canvas = Color(0xFFF3F4F8);
  static const column = Color(0xFFE8E9EF);
  static const counter = Color(0xFFDDDFE7);
  static const ink = Color(0xFF20212C);
  static const metadata = Color(0xFF626675);
  static const columnWidth = 320.0;
  static const toolbarHeight = 64.0;
  static const projectHeaderHeight = 104.0;
  static const cardTitleSize = 16.0;
  static const columnTitleSize = 16.0;
  static const iconSize = 22.0;

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : canvas;

  static Color listBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : column;

  static Color badgeBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : counter;

  static Color get accent => AppColors.accent;
}

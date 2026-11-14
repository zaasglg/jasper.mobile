import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const smMd = 12.0;
  static const md = 16.0;
  static const mdLg = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const touchTarget = 48.0;
}

abstract final class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class AppTypography {
  static TextStyle? title(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
  static TextStyle? body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;
  static TextStyle? caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall;

  static TextStyle? pageTitle(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall
      ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5);

  static TextStyle? taskTitle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3);
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_ui_tokens.dart';

/// Shared surface roles for the task detail page, without decorative borders.
abstract final class TaskDetailStyle {
  static const _field = Color(0xFFF3F4F7);
  static const metadataMinHeight = 96.0;

  static Color field(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : _field;

  static TextStyle? heading(BuildContext context) => AppTypography.title(
    context,
  )?.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle? label(BuildContext context) =>
      AppTypography.caption(context)?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

enum AppSnackBarTone { info, success, error }

/// A floating notice that keeps the Scaffold's keyboard and navigation insets.
SnackBar appSnackBar({
  required BuildContext context,
  required Widget content,
  AppSnackBarTone tone = AppSnackBarTone.info,
  String? description,
  SnackBarAction? action,
  Duration? duration,
  SnackBarBehavior behavior = SnackBarBehavior.floating,
}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final wide = MediaQuery.sizeOf(context).width >= 600;
  final floating = behavior == SnackBarBehavior.floating;
  return SnackBar(
    behavior: behavior,
    backgroundColor: dark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: dark ? theme.colorScheme.outlineVariant : AppColors.border,
      ),
    ),
    width: floating && wide ? 560 : null,
    margin: floating && !wide ? const EdgeInsets.fromLTRB(16, 0, 16, 16) : null,
    padding: const EdgeInsets.fromLTRB(14, 8, 0, 8),
    showCloseIcon: true,
    closeIconColor: dark ? theme.colorScheme.onSurfaceVariant : AppColors.muted,
    duration:
        duration ??
        Duration(
          seconds: switch (tone) {
            AppSnackBarTone.success => 3,
            AppSnackBarTone.info => 4,
            AppSnackBarTone.error => 6,
          },
        ),
    action: action,
    content: Theme(
      data: theme,
      child: _NoticeContent(
        tone: tone,
        description: description,
        child: content,
      ),
    ),
  );
}

class _NoticeContent extends StatelessWidget {
  const _NoticeContent({
    required this.tone,
    required this.child,
    this.description,
  });

  final AppSnackBarTone tone;
  final Widget child;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final textHeight = ((media.size.height - media.viewInsets.bottom) * 0.3)
        .clamp(64.0, 160.0);
    final color = switch (tone) {
      AppSnackBarTone.info => AppColors.accent,
      AppSnackBarTone.success => AppColors.success,
      AppSnackBarTone.error => AppColors.error,
    };
    final icon = switch (tone) {
      AppSnackBarTone.info => LucideIcons.info,
      AppSnackBarTone.success => LucideIcons.check,
      AppSnackBarTone.error => LucideIcons.circleAlert,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: textHeight),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                      child: child,
                    ),
                    if (description != null &&
                        description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

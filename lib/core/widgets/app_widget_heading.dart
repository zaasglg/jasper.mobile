import 'package:flutter/material.dart';
import '../theme/app_icon_sizes.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

class WidgetCollapseScope extends InheritedWidget {
  const WidgetCollapseScope({
    super.key,
    required this.onToggle,
    required super.child,
  });
  final VoidCallback onToggle;
  @override
  bool updateShouldNotify(WidgetCollapseScope oldWidget) =>
      onToggle != oldWidget.onToggle;
}

/// Shared title treatment for dashboard widgets and their embedded task panels.
class AppWidgetHeading extends StatelessWidget {
  const AppWidgetHeading({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.accent,
  });
  final IconData icon;
  final String title;
  final Color iconColor;
  static const textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: AppIconSizes.standard, color: iconColor),
      ),
      const SizedBox(width: AppSpacing.smMd),
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
      if (context.dependOnInheritedWidgetOfExactType<WidgetCollapseScope>()
          case final scope?)
        IconButton(
          key: const Key('dashboard_widget_collapse'),
          tooltip: 'Свернуть виджет',
          onPressed: scope.onToggle,
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: AppColors.muted,
          icon: const Icon(
            Icons.keyboard_arrow_up_rounded,
            size: AppIconSizes.standard,
          ),
        ),
    ],
  );
}

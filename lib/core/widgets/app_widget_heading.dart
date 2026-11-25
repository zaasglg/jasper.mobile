import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_icon_sizes.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

class WidgetCollapseScope extends InheritedWidget {
  const WidgetCollapseScope({
    super.key,
    required this.onToggle,
    this.expanded = true,
    this.hideHeading = false,
    this.memberCount,
    this.onMemberCountChanged,
    required super.child,
  });
  final VoidCallback onToggle;
  final bool expanded;
  final bool hideHeading;
  final int? memberCount;
  final ValueChanged<int>? onMemberCountChanged;
  static bool hidesHeading(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WidgetCollapseScope>()
          ?.hideHeading ??
      false;
  @override
  bool updateShouldNotify(WidgetCollapseScope oldWidget) =>
      onToggle != oldWidget.onToggle ||
      expanded != oldWidget.expanded ||
      hideHeading != oldWidget.hideHeading ||
      memberCount != oldWidget.memberCount ||
      onMemberCountChanged != oldWidget.onMemberCountChanged;
}

/// Shared title treatment for dashboard widgets and their embedded task panels.
class AppWidgetHeading extends StatelessWidget {
  const AppWidgetHeading({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.accent,
    this.fullWidthToggle = false,
    this.iconAsset,
    this.titleFontWeight,
    this.memberCount,
    this.toggleKey = const Key('dashboard_widget_collapse'),
    this.toggleSemanticLabel,
  });
  final IconData icon;
  final String title;
  final Color iconColor;
  final bool fullWidthToggle;
  final String? iconAsset;
  final FontWeight? titleFontWeight;
  final int? memberCount;
  final Key toggleKey;
  final String? toggleSemanticLabel;
  static const textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WidgetCollapseScope>();
    if (scope?.hideHeading == true) return const SizedBox.shrink();
    final fullWidth = scope != null;
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(
              fontWeight: titleFontWeight,
              color: AppColors.of(context).ink,
            ),
          ),
        ),
        if (memberCount != null) ...[
          const SizedBox(width: 8),
          Container(
            key: const Key('team-member-count'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.of(context).badgeSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tr(context, "{p0} чел.", {'p0': memberCount}),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.of(context).muted,
              ),
            ),
          ),
        ],
      ],
    );
    final heading = Row(
      mainAxisSize: scope != null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: iconAsset == null
              ? Icon(icon, size: AppIconSizes.standard, color: iconColor)
              : SvgPicture.asset(
                  iconAsset!,
                  width: AppIconSizes.standard,
                  height: AppIconSizes.standard,
                ),
        ),
        const SizedBox(width: AppSpacing.smMd),
        if (scope != null)
          Expanded(child: titleWidget)
        else
          Flexible(child: titleWidget),
        if (fullWidth)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              scope.expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 28,
              color: AppColors.of(context).muted,
            ),
          ),
      ],
    );
    if (!fullWidth) return heading;
    return Material(
      key: const Key('dashboard_widget_heading_surface'),
      color: Colors.transparent,
      child: InkWell(
        key: toggleKey,
        onTap: scope.onToggle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Semantics(
          button: true,
          label: toggleSemanticLabel ?? 'Скрыть $title',
          child: Padding(
            padding: fullWidthToggle
                ? const EdgeInsets.fromLTRB(18, 16, 12, 12)
                : EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: heading,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_icon_sizes.dart';
import '../theme/app_theme.dart';

/// Shared title treatment for dashboard widgets and their embedded task panels.
class AppWidgetHeading extends StatelessWidget {
  const AppWidgetHeading({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.muted,
  });
  final IconData icon;
  final String title;
  final Color iconColor;
  static const textStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.ink,
  );
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: AppIconSizes.standard, color: iconColor),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
    ],
  );
}

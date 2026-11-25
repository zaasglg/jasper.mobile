import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Unified back navigation button used across all screens.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.enabled = true,
    this.color,
    this.tooltip = 'Назад',
  });

  static const IconData icon = LucideIcons.arrowLeft;
  static const double iconSize = 20;

  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled
          ? (onPressed ?? () => Navigator.of(context).maybePop())
          : null,
      icon: Icon(icon, size: iconSize, color: color),
    );
  }
}

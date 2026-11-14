import 'package:flutter/material.dart';

import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import '../../../../core/theme/dashboard_surface.dart';

class DashboardCollapsibleWidget extends StatefulWidget {
  const DashboardCollapsibleWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  State<DashboardCollapsibleWidget> createState() =>
      _DashboardCollapsibleWidgetState();
}

class _DashboardCollapsibleWidgetState
    extends State<DashboardCollapsibleWidget> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_collapsed)
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: DashboardSurface.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('dashboard_widget_expand'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            title: AppWidgetHeading(icon: widget.icon, title: widget.title),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => setState(() => _collapsed = !_collapsed),
          ),
        ),
      Offstage(
        offstage: _collapsed,
        child: WidgetCollapseScope(
          onToggle: () => setState(() => _collapsed = true),
          child: widget.child,
        ),
      ),
    ],
  );
}

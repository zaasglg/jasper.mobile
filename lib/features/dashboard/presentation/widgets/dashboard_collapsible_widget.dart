import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_widget_heading.dart';

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

class _DashboardCollapsibleWidgetState extends State<DashboardCollapsibleWidget>
    with AutomaticKeepAliveClientMixin {
  bool _collapsed = false;
  int? _memberCount;

  void _updateMemberCount(int count) {
    if (mounted && _memberCount != count) {
      setState(() => _memberCount = count);
    }
  }

  // Retain loaded content and disclosure state outside the list's cache.
  // Recreating a card briefly restores its skeleton and changes its height,
  // forcing scroll corrections when the user returns to it.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final usesTextDisclosure = widget.title == tr(context, 'AI рекомендации');
    return AnimatedSize(
      key: const Key('dashboard_widget_size_animation'),
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          WidgetCollapseScope(
            expanded: !_collapsed,
            onToggle: () => setState(() => _collapsed = !_collapsed),
            child: AppWidgetHeading(
              icon: widget.icon,
              iconAsset: usesTextDisclosure ? 'assets/images/JBee.svg' : null,
              title: widget.title,
              memberCount: _memberCount,
              titleFontWeight: FontWeight.w600,
              fullWidthToggle: true,
              toggleKey: Key(
                _collapsed
                    ? 'dashboard_widget_expand'
                    : 'dashboard_widget_collapse',
              ),
              toggleSemanticLabel:
                  '${_collapsed ? 'Показать' : 'Скрыть'} ${widget.title}',
            ),
          ),
          Offstage(
            offstage: _collapsed,
            child: WidgetCollapseScope(
              hideHeading: true,
              memberCount: _memberCount,
              onMemberCountChanged: _updateMemberCount,
              onToggle: () => setState(() => _collapsed = true),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

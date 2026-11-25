import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DashboardPreviewScope extends InheritedWidget {
  const DashboardPreviewScope({
    required this.expanded,
    required super.child,
    super.key,
  });
  final bool expanded;
  static List<T> limit<T>(BuildContext context, List<T> items) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DashboardPreviewScope>();
    return scope == null || scope.expanded ? items : items.take(10).toList();
  }

  @override
  bool updateShouldNotify(DashboardPreviewScope oldWidget) =>
      oldWidget.expanded != expanded;
}

/// Keeps long mobile cards compact without introducing a nested scroll view.
class DashboardExpandableContent extends StatefulWidget {
  const DashboardExpandableContent({required this.child, super.key});

  final Widget child;

  @override
  State<DashboardExpandableContent> createState() =>
      _DashboardExpandableContentState();
}

class _DashboardExpandableContentState
    extends State<DashboardExpandableContent> {
  bool _expanded = false;
  bool _overflows = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          key: const ValueKey('dashboard-content-preview'),
          child: _ContentPreview(
            expanded: _expanded,
            onOverflow: (value) {
              if (mounted && value != _overflows) {
                setState(() => _overflows = value);
              }
            },
            child: DashboardPreviewScope(
              expanded: _expanded,
              child: widget.child,
            ),
          ),
        ),
        if (_overflows)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _expanded ? tr(context, 'Свернуть') : tr(context, 'Показать всё'),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ContentPreview extends SingleChildRenderObjectWidget {
  const _ContentPreview({
    required this.expanded,
    required this.onOverflow,
    required super.child,
  });

  final bool expanded;
  final ValueChanged<bool> onOverflow;

  @override
  _PreviewBox createRenderObject(BuildContext context) =>
      _PreviewBox(expanded, onOverflow);

  @override
  void updateRenderObject(BuildContext context, _PreviewBox renderObject) {
    renderObject
      ..onOverflow = onOverflow
      ..expanded = expanded;
  }
}

class _PreviewBox extends RenderProxyBox {
  _PreviewBox(this._expanded, this.onOverflow);

  static const double previewHeight = 360;
  bool _expanded;
  bool? _lastOverflow;
  ValueChanged<bool> onOverflow;

  set expanded(bool value) {
    if (value == _expanded) return;
    _expanded = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    final fullSize = child!.size;
    final overflow = fullSize.height > previewHeight;
    size = constraints.constrain(
      Size(
        fullSize.width,
        _expanded || !overflow ? fullSize.height : previewHeight,
      ),
    );
    if (_lastOverflow != overflow) {
      _lastOverflow = overflow;
      WidgetsBinding.instance.addPostFrameCallback((_) => onOverflow(overflow));
    }
  }
}

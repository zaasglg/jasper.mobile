import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Inset settings rows sharing the platform's grouped background and separators.
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    required this.children,
    this.dividerInset = 16,
  });
  final List<Widget> children;
  final double dividerInset;

  static Color pageColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF000000)
      : const Color(0xFFF2F2F7);
  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1C1C1E)
      : const Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) => Material(
    color: surfaceColor(context),
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsetsDirectional.only(start: dividerInset),
              child: Divider(
                height: .5,
                thickness: .5,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            ),
          children[i],
        ],
      ],
    ),
  );
}

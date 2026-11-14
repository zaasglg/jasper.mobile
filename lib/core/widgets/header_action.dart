import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/app_ui_tokens.dart';

class HeaderAction extends StatelessWidget {
  const HeaderAction({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    super.key,
  });
  final VoidCallback onPressed;
  final String tooltip;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.touchTarget,
    child: FButton.raw(
      key: ValueKey('header-$tooltip'),
      variant: FButtonVariant.ghost,
      onPress: onPressed,
      semanticsLabel: tooltip,
      semanticsTooltip: tooltip,
      child: Center(child: icon),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shared container for confirmations and compact editing dialogs.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.content,
    this.actions = const [],
    this.destructive = false,
    this.animateButtons = true,
    super.key,
  });

  final Widget title;
  final Widget? content;

  /// Keep cancel first and the main action last. Narrow layouts stack the main
  /// action above cancel without changing focus traversal order on wide screens.
  final List<Widget> actions;
  final bool destructive;
  final bool animateButtons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? theme.colorScheme.onSurface : AppColors.ink;
    return Dialog(
      backgroundColor: dark ? theme.colorScheme.surface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                namesRoute: true,
                header: true,
                child: DefaultTextStyle(
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                  child: title,
                ),
              ),
              if (content != null) ...[
                const SizedBox(height: 12),
                DefaultTextStyle(
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.5,
                    color: dark
                        ? theme.colorScheme.onSurfaceVariant
                        : const Color(0xFF686B7B),
                  ),
                  child: content!,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 17;
                    final buttons = [
                      for (var i = 0; i < actions.length; i++)
                        _action(context, actions[i], i == actions.length - 1),
                    ];
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = buttons.length - 1; i >= 0; i--) ...[
                            buttons[i],
                            if (i > 0) const SizedBox(height: 8),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: buttons[i]),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, Widget action, bool primary) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final style = TextButton.styleFrom(
      backgroundColor: primary
          ? (destructive ? AppColors.error : AppColors.accent)
          : (dark
                ? theme.colorScheme.surfaceContainerHighest
                : AppColors.subtleSurface),
      foregroundColor: primary
          ? Colors.white
          : (dark ? theme.colorScheme.onSurface : AppColors.ink),
      disabledBackgroundColor: dark
          ? theme.colorScheme.surfaceContainerHighest
          : AppColors.subtleSurface,
      disabledForegroundColor: AppColors.muted,
      minimumSize: const Size(48, 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.manrope(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    );
    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(style: style),
        filledButtonTheme: FilledButtonThemeData(style: style),
      ),
      child: _DialogPressFeedback(
        enabled:
            animateButtons &&
            action is ButtonStyleButton &&
            action.onPressed != null,
        child: action,
      ),
    );
  }
}

/// Fade-only transitions also work with the platform's reduced-motion setting.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) =>
        SafeArea(child: themes.wrap(builder(context))),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

Future<bool> showAppConfirmation(
  BuildContext context,
  String title,
  String message, {
  String confirmLabel = 'Подтвердить',
  bool destructive = false,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(title),
        content: Text(message),
        destructive: destructive,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

class _DialogPressFeedback extends StatefulWidget {
  const _DialogPressFeedback({required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  State<_DialogPressFeedback> createState() => _DialogPressFeedbackState();
}

class _DialogPressFeedbackState extends State<_DialogPressFeedback> {
  bool _pressed = false;
  void _setPressed(bool value) {
    if ((!value || widget.enabled) && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations || media.accessibleNavigation;
    final pressed = widget.enabled && _pressed;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: pressed && !reduced ? .96 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: pressed && reduced ? .8 : 1,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

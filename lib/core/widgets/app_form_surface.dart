import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/app_input_theme.dart';

/// Shared visual language for compact editing sheets.
class AppFormSurface extends StatelessWidget {
  const AppFormSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: AppInputTheme.light,
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: colors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          iconColor: colors.primary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class AppFormButton extends StatefulWidget {
  const AppFormButton({
    required this.onPressed,
    required this.child,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<AppFormButton> createState() => _AppFormButtonState();
}

class _AppFormButtonState extends State<AppFormButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_syncPressed);
  }

  void _syncPressed() {
    void update() {
      if (!mounted) return;
      final pressed = _states.value.contains(WidgetState.pressed);
      if (_pressed != pressed) setState(() => _pressed = pressed);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  @override
  void dispose() {
    _states.removeListener(_syncPressed);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pressed = widget.onPressed != null && _pressed;
    return AnimatedScale(
      scale: pressed && !media.disableAnimations && !media.accessibleNavigation
          ? .96
          : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: FilledButton(
        statesController: _states,
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: widget.child,
      ),
    );
  }
}

/// A stationary label keeps the field edge quiet while editing.
class AppFormField extends StatelessWidget {
  const AppFormField({required this.label, required this.child, super.key});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child,
    ],
  );
}

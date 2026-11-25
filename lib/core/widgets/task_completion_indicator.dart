import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared visual state for task completion; the parent owns the action.
class TaskCompletionIndicator extends StatelessWidget {
  const TaskCompletionIndicator({
    super.key,
    required this.completed,
    this.busy = false,
    this.size = 18,
  });

  final bool completed;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: completed,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? AppColors.success : Colors.transparent,
        border: Border.all(
          color: completed
              ? AppColors.success
              : Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: busy
          ? Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: completed ? Colors.white : AppColors.success,
              ),
            )
          : completed
          ? Icon(Icons.check_rounded, size: size * 0.7, color: Colors.white)
          : null,
    ),
  );
}

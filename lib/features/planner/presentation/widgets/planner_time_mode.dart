import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlannerTimeMode extends StatelessWidget {
  const PlannerTimeMode({
    super.key,
    required this.hasTime,
    required this.onChanged,
  });
  final bool hasTime;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: hasTime,
        padding: const EdgeInsets.all(3),
        backgroundColor: dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFF0F0F2),
        thumbColor: dark ? const Color(0xFF636366) : Colors.white,
        disabledChildren: onChanged == null ? const {false, true} : const {},
        onValueChanged: (value) {
          if (value != null && value != hasTime) onChanged?.call(value);
        },
        children: {
          for (final timed in [false, true])
            timed: ConstrainedBox(
              key: ValueKey(
                timed ? 'planner-mode-timed' : 'planner-mode-untimed',
              ),
              constraints: const BoxConstraints(minHeight: 38),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Center(
                  child: Text(
                    timed
                        ? tr(context, 'Указать время')
                        : tr(context, 'Весь день'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: hasTime == timed
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: onChanged == null
                          ? colors.onSurface.withValues(alpha: .4)
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        },
      ),
    );
  }
}

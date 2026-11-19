import 'package:flutter/material.dart';

class PlannerTimeMode extends StatelessWidget {
  const PlannerTimeMode({
    super.key,
    required this.hasTime,
    required this.onChanged,
  });
  final bool hasTime;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final timed in [false, true])
        ChoiceChip(
          key: ValueKey(timed ? 'planner-mode-timed' : 'planner-mode-untimed'),
          label: Text(timed ? 'Указать время' : 'Без времени'),
          selected: hasTime == timed,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onSelected: onChanged == null ? null : (_) => onChanged!(timed),
        ),
    ],
  );
}

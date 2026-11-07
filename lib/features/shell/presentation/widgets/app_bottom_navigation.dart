import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fontSize = width >= 600
              ? 15.0
              : width >= 420
              ? 14.0
              : width >= 375
              ? 13.0
              : 12.0;
          final spacious = width >= 420;
          return Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: Semantics(
                    label: destinations[index].label,
                    selected: index == selectedIndex,
                    button: true,
                    child: Tooltip(
                      message: destinations[index].label,
                      child: InkWell(
                        key: ValueKey('navigation-tab-$index'),
                        onTap: () => onSelected(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 8,
                          ),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: spacious ? 38 : 32,
                                  width: spacious ? 64 : 56,
                                  decoration: BoxDecoration(
                                    color: index == selectedIndex
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: .12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  alignment: Alignment.center,
                                  child: Transform.scale(
                                    scale: spacious ? 1.15 : 1,
                                    child: index == selectedIndex
                                        ? destinations[index].selectedIcon ??
                                              destinations[index].icon
                                        : destinations[index].icon,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      destinations[index].label,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontSize: fontSize,
                                            fontWeight: index == selectedIndex
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

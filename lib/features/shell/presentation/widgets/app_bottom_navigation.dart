import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../../../../core/theme/app_ui_tokens.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FTheme(
      data: theme.brightness == Brightness.dark
          ? FTheme.neutral.dark.touch
          : FTheme.neutral.light.touch,
      child: FBottomNavigationBar(
        safeAreaBottom: true,
        index: selectedIndex,
        onChange: onSelected,
        children: [
          for (final (index, destination) in destinations.indexed)
            FBottomNavigationBarItem(
              key: ValueKey('navigation-tab-$index'),
              semanticsLabel: destination.label,
              icon: SizedBox(
                height: AppSpacing.touchTarget,
                width: AppSpacing.touchTarget,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      size: AppSpacing.lg,
                      color: index == selectedIndex
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    child: destination.icon is Icon
                        ? Icon(
                            (destination.icon as Icon).icon,
                            size: AppSpacing.lg,
                            color: index == selectedIndex
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          )
                        : destination.icon,
                  ),
                ),
              ),
              label: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: index == selectedIndex
                      ? colors.primary
                      : colors.onSurfaceVariant,
                  fontWeight: index == selectedIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

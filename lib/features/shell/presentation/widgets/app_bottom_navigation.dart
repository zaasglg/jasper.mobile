import 'package:liquid_glass_fx/liquid_glass_fx.dart';
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
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final bar = FTheme(
      data: theme.brightness == Brightness.dark
          ? FTheme.neutral.dark.touch
          : FTheme.neutral.light.touch,
      child: FBottomNavigationBar(
        style: FBottomNavigationBarStyleDelta.delta(
          decoration: DecorationDelta.boxDelta(
            color: colors.surface.withValues(
              alpha: highContrast ? 1 : (dark ? .46 : .28),
            ),
            border: Border(
              top: BorderSide(
                color: colors.onSurface.withValues(alpha: dark ? .16 : .09),
                width: .5,
              ),
            ),
          ),
        ),
        safeAreaBottom: true,
        index: selectedIndex,
        onChange: onSelected,
        children: [
          for (final (index, destination) in destinations.indexed)
            FBottomNavigationBarItem(
              key: ValueKey('navigation-tab-$index'),
              semanticsLabel: destination.label,
              icon: SizedBox(
                height: 32,
                width: AppSpacing.lg,
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
              label: LayoutBuilder(
                builder: (context, constraints) {
                  final style =
                      (theme.textTheme.labelSmall ?? const TextStyle())
                          .copyWith(
                            height: 1.25,
                            color: index == selectedIndex
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: index == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                          );
                  // Fit every label using the longest one to keep one shared
                  // font size and a single baseline across all tabs.
                  var height = 0.0;
                  var width = 0.0;
                  for (final tab in destinations) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: tab.label,
                        style: style.copyWith(fontWeight: FontWeight.w600),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      locale: Localizations.localeOf(context),
                      maxLines: 1,
                    )..layout();
                    if (painter.height > height) height = painter.height;
                    if (painter.width > width) width = painter.width;
                    painter.dispose();
                  }
                  final fit = width > constraints.maxWidth
                      ? constraints.maxWidth / width
                      : 1.0;
                  final fontSize = style.fontSize ?? 11;
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(fontSize) /
                      fontSize;
                  return SizedBox(
                    height: height * fit,
                    width: constraints.maxWidth,
                    child: Text(
                      destination.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      textScaler: TextScaler.linear(textScale * fit),
                      overflow: TextOverflow.visible,
                      style: style,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
    if (highContrast) return bar;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LiquidGlass(
              borderRadius: 0,
              interactive: false,
              quality: LiquidGlassQuality.high,
              blurSigma: 8,
              refractionStrength: .65,
              highlightIntensity: .55,
              chromaticAberration: .03,
              tint: colors.surface.withValues(alpha: dark ? .12 : .08),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        bar,
      ],
    );
  }
}

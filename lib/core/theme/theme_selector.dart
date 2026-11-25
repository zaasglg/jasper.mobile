import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/app_snack_bar.dart';
import 'theme_cubit.dart';
import 'app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, required this.cubit, this.onSelected});

  final ThemeCubit cubit;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return BlocBuilder<ThemeCubit, ThemeMode>(
      bloc: cubit,
      builder: (context, selected) => RadioGroup<ThemeMode>(
        groupValue: selected,
        onChanged: (value) async {
          if (value == null) return;
          try {
            await cubit.select(value);
          } catch (error, stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'theme preferences',
                context: ErrorDescription(
                  'while persisting the appearance choice',
                ),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                appSnackBar(
                  context: context,
                  tone: AppSnackBarTone.error,
                  content: Text(
                    tr(
                      context,
                      'Тема применена, но не сохранена. Попробуйте ещё раз.',
                    ),
                  ),
                ),
              );
            }
            return;
          }
          if (context.mounted) onSelected?.call();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                tr(context, 'Тема приложения'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final mode in ThemeMode.values)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: selected == mode
                      ? colors.accent.withValues(alpha: .08)
                      : colors.subtleSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected == mode
                          ? colors.accent.withValues(alpha: .4)
                          : Colors.transparent,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<ThemeMode>(
                    value: mode,
                    activeColor: colors.accent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(
                      switch (mode) {
                        ThemeMode.system => tr(context, 'Системная'),
                        ThemeMode.light => tr(context, 'Светлая'),
                        ThemeMode.dark => tr(context, 'Тёмная'),
                      },
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    secondary: Icon(
                      switch (mode) {
                        ThemeMode.system => LucideIcons.monitor,
                        ThemeMode.light => LucideIcons.sun,
                        ThemeMode.dark => LucideIcons.moon,
                      },
                      size: 21,
                      color: selected == mode ? colors.accent : colors.muted,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';

class DashboardWelcomeHeader extends StatelessWidget {
  const DashboardWelcomeHeader({
    super.key,
    this.name = 'Пользователь',
    this.onEdit,
    this.onCreate,
  });
  final String name;
  final VoidCallback? onEdit;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => FTheme(
    data: FThemeData(
      touch: true,
      colors: FTheme.neutral.light.touch.colors.copyWith(
        primary: AppColors.accent,
        primaryForeground: Colors.white,
      ),
    ),
    child: ColoredBox(
      color: AppColors.of(context).canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(context, 'Приветствую,'),
                    style: AppTypography.body(
                      context,
                    )?.copyWith(color: AppColors.of(context).muted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.of(context).ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.of(context).border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WelcomeAction(
                    label: 'Редактировать виджеты',
                    icon: LucideIcons.pencil,
                    onPress: onEdit,
                  ),
                  _WelcomeAction(
                    label: 'Добавить задачу',
                    icon: LucideIcons.plus,
                    onPress: onCreate,
                    primary: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    required this.label,
    required this.icon,
    this.onPress,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPress;
  final bool primary;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.touchTarget,
    child: FButton.raw(
      key: ValueKey('welcome-$label'),
      variant: FButtonVariant.ghost,
      onPress: onPress,
      semanticsLabel: label,
      semanticsTooltip: label,
      child: Center(
        child: Container(
          width: AppSpacing.touchTarget - AppSpacing.sm,
          height: AppSpacing.touchTarget - AppSpacing.sm,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md - AppSpacing.xs),
          ),
          child: Icon(
            icon,
            size: AppSpacing.md + AppSpacing.xs,
            color: primary ? Colors.white : AppColors.of(context).ink,
          ),
        ),
      ),
    ),
  );
}

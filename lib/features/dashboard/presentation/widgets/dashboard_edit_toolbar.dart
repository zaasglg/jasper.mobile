import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_ui_tokens.dart';

class DashboardEditToolbar extends StatelessWidget {
  const DashboardEditToolbar({
    super.key,
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.onAdd,
    required this.onReset,
  });
  final bool saving;
  final VoidCallback onCancel, onSave, onAdd, onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Редактирование виджетов'),
                    style: AppTypography.title(context),
                  ),
                ),
                IconButton(
                  key: const Key('dashboard_edit_cancel'),
                  tooltip: tr(context, 'Отмена'),
                  onPressed: saving ? null : onCancel,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.touchTarget,
                    minHeight: AppSpacing.touchTarget,
                  ),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            Text(
              tr(context, 'Перетаскивайте виджеты, чтобы изменить порядок'),
              style: AppTypography.caption(
                context,
              )?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('dashboard_edit_add'),
                    onPressed: saving ? null : onAdd,
                    icon: const Icon(LucideIcons.plus),
                    label: Text(tr(context, 'Добавить виджет')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.touchTarget),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  key: const Key('dashboard_edit_reset'),
                  tooltip: tr(context, 'Сбросить виджеты'),
                  onPressed: saving ? null : onReset,
                  icon: const Icon(LucideIcons.rotateCcw),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const Key('dashboard_edit_save'),
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
              ),
              icon: const Icon(LucideIcons.check),
              label: Text(
                saving ? tr(context, 'Сохранение…') : tr(context, 'Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:jospar/core/localization/app_translations.dart';
import '../theme/app_icon_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

/// Presentation configuration for one action in an app menu.
class AppMenuAction<T> {
  const AppMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.destructive = false,
    this.muted = false,
    this.opensSubmenu = false,
    this.selected = false,
  });
  final T value;
  final String label;
  final IconData icon;
  final bool enabled, destructive, muted, opensSubmenu, selected;
}

Future<T?> showAppActionMenu<T>(
  BuildContext context, {
  required String title,
  String? eyebrow,
  required List<List<AppMenuAction<T>>> groups,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => AppActionSheet<T>(
      title: title,
      eyebrow: eyebrow,
      groups: groups,
      onSelected: (value) => Navigator.pop(sheetContext, value),
      onCancel: () => Navigator.pop(sheetContext),
    ),
  );
}

class AppActionMenuButton<T> extends StatelessWidget {
  const AppActionMenuButton({
    super.key,
    required this.title,
    required this.groups,
    required this.onSelected,
    this.eyebrow,
    this.tooltip = 'Действия',
    this.enabled = true,
    this.icon = LucideIcons.ellipsis,
    this.child,
  });
  final String title, tooltip;
  final String? eyebrow;
  final List<List<AppMenuAction<T>>> groups;
  final FutureOr<void> Function(T) onSelected;
  final bool enabled;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Future<void> open() async {
      final value = await showAppActionMenu<T>(
        context,
        title: title,
        eyebrow: eyebrow,
        groups: groups,
      );
      if (value != null && context.mounted) {
        await onSelected(value);
      }
    }

    if (child != null) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? open : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? open : null,
      icon: Icon(icon, size: AppIconSizes.standard),
      visualDensity: VisualDensity.compact,
    );
  }
}

class AppActionSheet<T> extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.title,
    required this.groups,
    required this.onSelected,
    required this.onCancel,
    this.eyebrow,
  });
  final String title;
  final String? eyebrow;
  final List<List<AppMenuAction<T>>> groups;
  final ValueChanged<T> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = this.groups.where((group) => group.isNotEmpty).toList();
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(
                      tr(context, eyebrow!),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  if (eyebrow != null) const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr(context, 'Нет доступных вариантов'),
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    for (var index = 0; index < groups.length; index++) ...[
                      if (index > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Divider(
                            height: 1,
                            color: colors.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      for (final action in groups[index])
                        _AppActionRow<T>(
                          action: action,
                          onTap: () => onSelected(action.value),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    backgroundColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(tr(context, 'Отмена')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppActionRow<T> extends StatelessWidget {
  const _AppActionRow({required this.action, required this.onTap});
  final AppMenuAction<T> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive = action.destructive;
    final enabled = action.enabled;
    final foreground = !enabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : destructive
        ? colors.error
        : colors.onSurface;
    final iconColor = !enabled
        ? colors.onSurface.withValues(alpha: 0.3)
        : destructive
        ? colors.error
        : action.muted
        ? colors.onSurfaceVariant
        : AppColors.accent;
    final nextStep = action.opensSubmenu;
    return Semantics(
      selected: action.selected,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    action.icon,
                    size: AppIconSizes.standard,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tr(context, action.label),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (action.selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.check,
                    size: AppIconSizes.standard,
                    color: AppColors.accent,
                  ),
                ] else if (nextStep) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: AppIconSizes.standard,
                    color: colors.onSurfaceVariant.withValues(
                      alpha: enabled ? 0.55 : 0.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

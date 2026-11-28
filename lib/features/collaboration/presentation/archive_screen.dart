import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_ui_tokens.dart';
import '../../../core/theme/dashboard_surface.dart';
import '../../../core/widgets/app_action_menu.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/collaboration_repository.dart';
import '../domain/entities/managed_space.dart';
import '../domain/entities/space_kind.dart';

class ArchiveState extends Equatable {
  const ArchiveState({
    this.items = const [],
    this.loading = true,
    this.busyId,
    this.error,
  });

  final List<ManagedSpace> items;
  final bool loading;
  final String? busyId;
  final String? error;

  @override
  List<Object?> get props => [items, loading, busyId, error];
}

class ArchiveCubit extends Cubit<ArchiveState> {
  ArchiveCubit(this.repository, this.kind, this.workspaceId)
    : super(const ArchiveState());

  final CollaborationRepository repository;
  final SpaceKind kind;
  final String? workspaceId;
  int _loadRevision = 0;

  Future<void> load() async {
    if (isClosed || state.busyId != null) return;
    final revision = ++_loadRevision;
    emit(ArchiveState(items: state.items));
    try {
      final items = await repository.archived(kind, workspaceId: workspaceId);
      if (!isClosed && revision == _loadRevision) {
        emit(ArchiveState(items: items, loading: false));
      }
    } catch (e) {
      if (!isClosed && revision == _loadRevision) {
        emit(
          ArchiveState(items: state.items, loading: false, error: e.toString()),
        );
      }
    }
  }

  Future<void> act(String id, bool remove) async {
    if (isClosed || state.busyId != null) return;
    ++_loadRevision;
    emit(ArchiveState(items: state.items, loading: false, busyId: id));
    try {
      if (remove) {
        await repository.delete(kind, id);
      } else {
        await repository.restore(kind, id);
      }
      if (!isClosed) {
        emit(
          ArchiveState(
            items: state.items.where((e) => e.id != id).toList(),
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ArchiveState(items: state.items, loading: false, error: e.toString()),
        );
      }
    }
  }
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({required this.kind, this.workspaceId, super.key});

  final SpaceKind kind;
  final String? workspaceId;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _handleAction(
    BuildContext context,
    ManagedSpace item,
    String value,
  ) async {
    if (value == 'delete' &&
        !await showAppConfirmation(
          context,
          tr(context, 'Удалить навсегда?'),
          tr(context, 'Это действие нельзя отменить.'),
          confirmLabel: 'Удалить',
          destructive: true,
        )) {
      return;
    }
    if (context.mounted) {
      await context.read<ArchiveCubit>().act(item.id, value == 'delete');
    }
  }

  List<List<AppMenuAction<String>>> _menuGroups(BuildContext context) => [
    [
      AppMenuAction(
        value: 'restore',
        label: tr(context, 'Восстановить'),
        icon: LucideIcons.archiveRestore,
      ),
    ],
    [
      AppMenuAction(
        value: 'delete',
        label: tr(context, 'Удалить навсегда'),
        icon: LucideIcons.trash2,
        destructive: true,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.kind == SpaceKind.project
        ? tr(context, 'Архив проектов')
        : tr(context, 'Архив workspace');

    return BlocProvider(
      create: (_) => ArchiveCubit(
        sl<CollaborationRepository>(),
        widget.kind,
        widget.workspaceId,
      )..load(),
      child: BlocConsumer<ArchiveCubit, ArchiveState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context: context,
                tone: AppSnackBarTone.error,
                content: Text(tr(context, state.error!)),
              ),
            );
          }
        },
        builder: (context, state) {
          final query = _search.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? state.items
              : state.items.where((item) {
                  final name = item.name.toLowerCase();
                  final code = item.code?.toLowerCase() ?? '';
                  final desc = item.description?.toLowerCase() ?? '';
                  return name.contains(query) ||
                      code.contains(query) ||
                      desc.contains(query);
                }).toList();

          return Scaffold(
            backgroundColor: isDark ? colors.canvas : const Color(0xFFF8F9FC),
            appBar: AppBar(
              backgroundColor: isDark ? colors.canvas : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: const AppBackButton(),
              title: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? colors.border : const Color(0xFFEBEFF5),
                ),
              ),
            ),
            body: state.loading && state.items.isEmpty
                ? Center(child: CircularProgressIndicator(color: colors.accent))
                : Column(
                    children: [
                      if (state.loading)
                        LinearProgressIndicator(
                          minHeight: 2,
                          color: colors.accent,
                        ),
                      if (state.items.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ArchiveSearchField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                onClear: () => setState(_search.clear),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Text(
                                    tr(context, 'В архиве').toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.65,
                                      color: colors.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.outgoingMessage,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${filtered.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.accent,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          color: colors.accent,
                          onRefresh: context.read<ArchiveCubit>().load,
                          child: _ArchiveBody(
                            kind: widget.kind,
                            state: state,
                            filtered: filtered,
                            hasQuery: query.isNotEmpty,
                            onClearSearch: () => setState(_search.clear),
                            onRetry: context.read<ArchiveCubit>().load,
                            menuGroups: _menuGroups(context),
                            onAction: (item, value) =>
                                _handleAction(context, item, value),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _ArchiveBody extends StatelessWidget {
  const _ArchiveBody({
    required this.kind,
    required this.state,
    required this.filtered,
    required this.hasQuery,
    required this.onClearSearch,
    required this.onRetry,
    required this.menuGroups,
    required this.onAction,
  });

  final SpaceKind kind;
  final ArchiveState state;
  final List<ManagedSpace> filtered;
  final bool hasQuery;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRetry;
  final List<List<AppMenuAction<String>>> menuGroups;
  final Future<void> Function(ManagedSpace item, String value) onAction;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          bottom,
        ),
        children: [
          _ArchiveEmptyState(
            isError: state.error != null,
            icon: state.error != null
                ? LucideIcons.circleAlert
                : LucideIcons.archive,
            title: state.error != null
                ? tr(context, 'Не удалось загрузить архив')
                : tr(context, 'Архив пуст'),
            subtitle: state.error != null
                ? tr(context, 'Проверьте подключение и попробуйте снова.')
                : kind == SpaceKind.project
                ? tr(
                    context,
                    'Архивированные проекты появятся здесь. Их можно восстановить или удалить навсегда.',
                  )
                : tr(
                    context,
                    'Архивированные пространства появятся здесь. Их можно восстановить или удалить навсегда.',
                  ),
            actionLabel: state.error != null ? tr(context, 'Повторить') : null,
            onAction: state.error != null ? () => unawaited(onRetry()) : null,
          ),
        ],
      );
    }

    if (filtered.isEmpty && hasQuery) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          bottom,
        ),
        children: [
          _ArchiveEmptyState(
            isError: false,
            icon: LucideIcons.search,
            title: tr(context, 'Ничего не найдено'),
            subtitle: tr(context, 'Попробуйте изменить поисковый запрос.'),
            actionLabel: tr(context, 'Сбросить поиск'),
            onAction: onClearSearch,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.smMd,
        AppSpacing.md,
        bottom,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _ArchiveItemCard(
          kind: kind,
          item: item,
          isBusy: state.busyId == item.id,
          menuGroups: menuGroups,
          onAction: (value) => onAction(item, value),
        );
      },
    );
  }
}

class _ArchiveSearchField extends StatelessWidget {
  const _ArchiveSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? colors.border : const Color(0xFFE8EAF0);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.accent, width: 1.5),
    );

    return TextField(
      key: const Key('archive-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.inter(fontSize: 14, color: colors.ink),
      cursorColor: colors.accent,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: tr(context, 'Поиск в архиве'),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: colors.muted),
        prefixIcon: Icon(
          LucideIcons.search,
          size: AppIconSizes.standard,
          color: colors.muted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('archive-search-clear'),
                tooltip: tr(context, 'Очистить поиск'),
                onPressed: onClear,
                icon: Icon(
                  LucideIcons.x,
                  size: AppIconSizes.standard,
                  color: colors.muted,
                ),
              ),
        filled: true,
        fillColor: isDark ? colors.subtleSurface : Colors.white,
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smMd,
          vertical: AppSpacing.smMd,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
      ),
    );
  }
}

class _ArchiveItemCard extends StatelessWidget {
  const _ArchiveItemCard({
    required this.kind,
    required this.item,
    required this.isBusy,
    required this.menuGroups,
    required this.onAction,
  });

  final SpaceKind kind;
  final ManagedSpace item;
  final bool isBusy;
  final List<List<AppMenuAction<String>>> menuGroups;
  final Future<void> Function(String value) onAction;

  Color _badgeColor(AppPalette colors) {
    var hex = item.color?.replaceFirst('#', '').trim();
    if (hex != null) {
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6 || hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
        }
      }
    }
    return colors.accent;
  }

  Future<void> _openMenu(BuildContext context) async {
    final value = await showAppActionMenu<String>(
      context,
      title: item.name.trim().isEmpty ? tr(context, 'Без названия') : item.name,
      groups: menuGroups,
    );
    if (value != null && context.mounted) {
      await onAction(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = _badgeColor(colors);
    final title = item.name.trim().isEmpty
        ? tr(context, 'Без названия')
        : item.name;
    final code = item.code?.trim();
    final description = item.description?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colors.subtleSurface : DashboardSurface.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? colors.border : DashboardSurface.border,
        ),
        boxShadow: isDark ? const [] : DashboardSurface.shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isBusy ? null : () => _openMenu(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    kind == SpaceKind.project
                        ? LucideIcons.folder
                        : LucideIcons.layers,
                    size: 19,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.badgeSurface
                                  : const Color(0xFFF1F3F8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr(context, 'В архиве'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.muted,
                              ),
                            ),
                          ),
                          if (code != null && code.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isBusy)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
                  )
                else
                  AppActionMenuButton<String>(
                    title: title,
                    groups: menuGroups,
                    onSelected: onAction,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.badgeSurface
                            : const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 18,
                        color: colors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState({
    required this.isError,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final bool isError;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isError ? colors.error : colors.accent;
    final iconBg = isError
        ? colors.error.withValues(alpha: isDark ? 0.2 : 0.1)
        : colors.outgoingMessage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? colors.subtleSurface : DashboardSurface.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? colors.border : DashboardSurface.border,
        ),
        boxShadow: isDark ? const [] : DashboardSurface.shadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.45,
              color: colors.muted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

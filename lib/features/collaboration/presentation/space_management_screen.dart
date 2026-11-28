import 'package:jospar/core/localization/app_translations.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/theme/app_ui_tokens.dart';
import '../../../core/widgets/app_color_picker.dart';
import '../../../core/widgets/app_dialog.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/dashboard_surface.dart';
import '../../../core/widgets/app_action_menu.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_form_surface.dart';
import '../domain/entities/managed_space.dart';
import '../domain/entities/space_kind.dart';
import '../domain/entities/member_role.dart';
import '../domain/collaboration_repository.dart';
import 'collaboration_cubit.dart';
import 'workspace_participants_panel.dart';

class SpaceManagementScreen extends StatelessWidget {
  const SpaceManagementScreen({
    required this.kind,
    required this.id,
    super.key,
  });
  final SpaceKind kind;
  final String id;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        CollaborationCubit(sl<CollaborationRepository>(), kind, id)..load(),
    child: const _ManagementBody(),
  );
}

class _ManagementBody extends StatelessWidget {
  const _ManagementBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CollaborationCubit, CollaborationState>(
    listenWhen: (a, b) => a.error != b.error && b.error != null,
    listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context: context,
        tone: AppSnackBarTone.error,
        content: Text(tr(context, state.error!)),
      ),
    ),
    builder: (context, state) {
      final cubit = context.read<CollaborationCubit>();
      final space = state.space;
      final colors = AppColors.of(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dividerColor = isDark ? colors.border : const Color(0xFFF1F5F9);
      return Scaffold(
        backgroundColor: isDark ? colors.canvas : const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: isDark ? colors.canvas : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const AppBackButton(),
          title: Text(
            tr(context, "Настройки {p0}", {
              'p0': cubit.kind == SpaceKind.project ? 'проекта' : 'workspace',
            }),
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
        body: space == null
            ? Center(
                child: state.loading
                    ? CircularProgressIndicator(color: colors.accent)
                    : TextButton(
                        onPressed: cubit.load,
                        child: Text(tr(context, 'Повторить загрузку')),
                      ),
              )
            : SafeArea(
                top: false,
                child: AppFormSurface(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      if (state.loading || state.saving)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: colors.accent,
                          ),
                        ),
                      _SettingsSectionLabel(
                        text: tr(
                          context,
                          cubit.kind == SpaceKind.project
                              ? 'Основные данные'
                              : 'Основные настройки',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingsCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: _SpaceFields(
                            key: ValueKey(space),
                            space: space,
                            kind: cubit.kind,
                            saving: state.saving,
                            onSave: (changes) => cubit.run(
                              () => cubit.repository.updateSpace(
                                cubit.kind,
                                cubit.id,
                                changes,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.mdLg),
                      if (cubit.kind == SpaceKind.project) ...[
                        _SettingsSectionLabel(text: tr(context, 'Доступ')),
                        const SizedBox(height: AppSpacing.sm),
                        _SettingsCard(
                          child: _ActionTile(
                            icon: LucideIcons.users,
                            iconColor: colors.accent,
                            iconBg: colors.outgoingMessage,
                            title: tr(context, 'Участники'),
                            subtitle: tr(
                              context,
                              "Пользователей с доступом: {p0}",
                              {'p0': state.members.length},
                            ),
                            onTap: () async {
                              await context.push(
                                '/projects/${cubit.id}/participants',
                              );
                              if (!cubit.isClosed) await cubit.load();
                            },
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(context, "Участники · {p0}", {
                                  'p0': state.members.length,
                                }),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: tr(context, 'Добавить участника'),
                              onPressed: state.saving
                                  ? null
                                  : () => _addMember(context, cubit, state),
                              icon: const Icon(
                                LucideIcons.userPlus,
                                size: AppIconSizes.standard,
                              ),
                            ),
                          ],
                        ),
                        if (state.error != null && state.members.isEmpty)
                          TextButton(
                            onPressed: cubit.load,
                            child: Text(
                              tr(context, 'Повторить загрузку участников'),
                            ),
                          ),
                        WorkspaceParticipantsPanel(
                          members: state.members,
                          actions: (member) =>
                              member.role == 'OWNER' || member.isWorkspaceOwner
                              ? null
                              : AppActionMenuButton<String>(
                                  title: member.name,
                                  tooltip: tr(context, 'Действия участника'),
                                  groups: [
                                    [
                                      for (final role in memberRoles.entries)
                                        AppMenuAction(
                                          value: role.key,
                                          label: role.value,
                                          icon: LucideIcons.shield,
                                          selected: role.key == member.role,
                                        ),
                                    ],
                                    [
                                      AppMenuAction(
                                        value: 'remove',
                                        label: tr(
                                          context,
                                          'Удалить из участников',
                                        ),
                                        icon: LucideIcons.userMinus,
                                        destructive: true,
                                      ),
                                    ],
                                  ],
                                  onSelected: (value) async {
                                    if (state.saving) return;
                                    if (value == 'remove') {
                                      if (!await showAppConfirmation(
                                        context,
                                        tr(context, 'Удалить участника?'),
                                        tr(
                                          context,
                                          "{p0} потеряет доступ к этому разделу.",
                                          {'p0': member.name},
                                        ),
                                        confirmLabel: 'Удалить',
                                        destructive: true,
                                      )) {
                                        return;
                                      }
                                      await cubit.run(
                                        () => cubit.repository.removeMember(
                                          cubit.kind,
                                          cubit.id,
                                          member.userId,
                                        ),
                                      );
                                    } else {
                                      await cubit.run(
                                        () => cubit.repository.updateRole(
                                          cubit.kind,
                                          cubit.id,
                                          member.userId,
                                          value,
                                        ),
                                      );
                                    }
                                  },
                                ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.mdLg),
                      _SettingsSectionLabel(text: tr(context, 'Управление')),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingsCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionTile(
                              icon: LucideIcons.archive,
                              iconColor: colors.ink,
                              iconBg: isDark
                                  ? colors.badgeSurface
                                  : const Color(0xFFF1F3F8),
                              title: tr(context, 'Архивировать'),
                              onTap: state.saving
                                  ? null
                                  : () async {
                                      if (!await showAppConfirmation(
                                        context,
                                        tr(context, "Архивировать {p0}?", {
                                          'p0': cubit.kind.label.toLowerCase(),
                                        }),
                                        tr(
                                          context,
                                          'Вы сможете восстановить его из архива.',
                                        ),
                                        confirmLabel: 'Архивировать',
                                        destructive: false,
                                      )) {
                                        return;
                                      }
                                      if (await cubit.run(
                                            () => cubit.repository.archive(
                                              cubit.kind,
                                              cubit.id,
                                            ),
                                            reload: false,
                                          ) &&
                                          context.mounted) {
                                        context.pop('removed');
                                      }
                                    },
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            _ActionTile(
                              icon: LucideIcons.trash2,
                              iconColor: colors.error,
                              iconBg: colors.error.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                              title: tr(context, 'Удалить'),
                              titleColor: colors.error,
                              chevronColor: colors.error.withValues(alpha: 0.7),
                              onTap: state.saving
                                  ? null
                                  : () async {
                                      if (!await showAppConfirmation(
                                        context,
                                        tr(context, "Удалить {p0}?", {
                                          'p0': cubit.kind.label.toLowerCase(),
                                        }),
                                        tr(
                                          context,
                                          'Это действие нельзя отменить. Связанные данные могут быть удалены.',
                                        ),
                                        confirmLabel: 'Удалить',
                                        destructive: true,
                                      )) {
                                        return;
                                      }
                                      if (await cubit.run(
                                            () => cubit.repository.delete(
                                              cubit.kind,
                                              cubit.id,
                                            ),
                                            reload: false,
                                          ) &&
                                          context.mounted) {
                                        context.pop('removed');
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );

  Future<void> _addMember(
    BuildContext context,
    CollaborationCubit cubit,
    CollaborationState state,
  ) async {
    try {
      final candidates = await cubit.repository.candidates(
        cubit.kind == SpaceKind.project ? state.space!.workspaceId ?? '' : '',
      );
      if (!context.mounted) return;
      final available = candidates
          .where((user) => !state.members.any((m) => m.userId == user.userId))
          .toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.info,
            content: Text(
              tr(context, 'Все доступные пользователи уже добавлены.'),
            ),
          ),
        );
        return;
      }
      final selected = await showAppActionMenu<String>(
        context,
        title: 'Добавить участника',
        groups: [
          [
            for (final user in available)
              AppMenuAction(
                value: user.userId,
                label: user.name.isEmpty ? user.email : user.name,
                icon: LucideIcons.userRound,
              ),
          ],
        ],
      );
      if (selected != null) {
        await cubit.run(
          () => cubit.repository.addMember(
            cubit.kind,
            cubit.id,
            cubit.kind == SpaceKind.project
                ? available.firstWhere((user) => user.userId == selected).email
                : selected,
            'EXECUTOR',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }
}

class _SpaceFields extends StatefulWidget {
  const _SpaceFields({
    required this.space,
    required this.kind,
    required this.saving,
    required this.onSave,
    super.key,
  });
  final ManagedSpace space;
  final SpaceKind kind;
  final bool saving;
  final Future<bool> Function(Map<String, dynamic>) onSave;
  @override
  State<_SpaceFields> createState() => _SpaceFieldsState();
}

class _SpaceFieldsState extends State<_SpaceFields> {
  late final _name = TextEditingController(text: widget.space.name);
  late final _code = TextEditingController(text: widget.space.code ?? '');
  late final _description = TextEditingController(
    text: widget.space.description ?? '',
  );
  late final _color = TextEditingController(
    text: widget.space.color ?? '#6D5FE0',
  );
  late final _logo = TextEditingController(text: widget.space.logoUrl ?? '');
  late bool _pinned = widget.space.isPinned;
  bool _pickingLogo = false;
  int _logoRequest = 0;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _color.dispose();
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppFormField(
        label: tr(context, 'Название'),
        child: TextField(
          key: const Key('project_settings_name'),
          textInputAction: TextInputAction.next,
          controller: _name,
          enabled: !widget.saving,
          decoration: InputDecoration(errorText: trn(context, _error)),
        ),
      ),
      if (widget.kind == SpaceKind.project) ...[
        const SizedBox(height: 16),
        AppFormField(
          label: tr(context, 'Код проекта'),
          child: TextField(
            key: const Key('project_settings_code'),
            controller: _code,
            enabled: !widget.saving,
          ),
        ),
        const SizedBox(height: 16),
        AppFormField(
          label: tr(context, 'Описание · необязательно'),
          child: TextField(
            controller: _description,
            enabled: !widget.saving,
            minLines: 2,
            maxLines: 5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.of(context).subtleSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.of(context).border
                  : const Color(0xFFE8EAF0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.of(context).outgoingMessage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.pin,
                  size: 17,
                  color: AppColors.of(context).accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(context, 'Закрепить проект'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, 'Показывать в начале списка'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _pinned,
                activeTrackColor: AppColors.accent,
                onChanged: widget.saving
                    ? null
                    : (value) => setState(() => _pinned = value),
              ),
            ],
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        AppFormField(
          label: tr(context, 'Цвет'),
          child: AppColorPicker(
            value: _color.text,
            enabled: !widget.saving,
            onChanged: (value) => setState(() => _color.text = value),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: widget.saving || _pickingLogo ? null : _pickLogo,
                icon: const Icon(
                  LucideIcons.image,
                  size: AppIconSizes.standard,
                ),
                label: Text(
                  _pickingLogo
                      ? tr(context, 'Загрузка…')
                      : _logo.text.isEmpty
                      ? tr(context, 'Добавить логотип')
                      : tr(context, 'Заменить логотип'),
                ),
              ),
            ),
            if (_logo.text.isNotEmpty || _pickingLogo)
              IconButton(
                tooltip: _pickingLogo
                    ? tr(context, 'Отменить загрузку')
                    : tr(context, 'Убрать логотип'),
                onPressed: widget.saving
                    ? null
                    : () => setState(() {
                        _logoRequest++;
                        if (_pickingLogo) {
                          _pickingLogo = false;
                        } else {
                          _logo.clear();
                        }
                      }),
                icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
              ),
          ],
        ),
      ],
      if (_error != null)
        Text(
          tr(context, _error!),
          style: TextStyle(color: AppColors.of(context).error),
        ),
      const SizedBox(height: 20),
      AppFormButton(
        key: const Key('project_settings_save'),
        onPressed: widget.saving || _pickingLogo
            ? null
            : () async {
                if (_name.text.trim().isEmpty) {
                  setState(() => _error = 'Введите название');
                  return;
                }
                if (widget.kind == SpaceKind.workspace &&
                    !RegExp(
                      r'^#[0-9a-fA-F]{6}$',
                    ).hasMatch(_color.text.trim())) {
                  setState(() => _error = 'Укажите цвет в формате #RRGGBB');
                  return;
                }
                setState(() => _error = null);
                await widget.onSave({
                  'name': _name.text.trim(),
                  if (widget.kind == SpaceKind.project) ...{
                    'code': _code.text.trim(),
                    'description': _description.text.trim(),
                    'isPinned': _pinned,
                  },
                  if (widget.kind == SpaceKind.workspace) ...{
                    'color': _color.text.trim(),
                    if (_logo.text != (widget.space.logoUrl ?? ''))
                      'logoUrl': _logo.text.isEmpty ? null : _logo.text,
                  },
                });
              },
        child: Text(
          widget.saving ? tr(context, 'Сохранение…') : tr(context, 'Сохранить'),
          style: AppTypography.body(context)?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
  Future<void> _pickLogo() async {
    final request = ++_logoRequest;
    setState(() {
      _pickingLogo = true;
      _error = null;
    });
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (!mounted || request != _logoRequest) return;
      if (files.isEmpty) return;
      if ((await files.first.length() ?? 0) > 20 * 1024 * 1024) {
        throw const FormatException('Выберите изображение размером до 20 МБ');
      }
      final codec = await ui.instantiateImageCodec(
        await files.first.readAsBytes(),
        targetWidth: 256,
        targetHeight: 256,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data != null && mounted && request == _logoRequest) {
            setState(
              () => _logo.text =
                  'data:image/png;base64,${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}',
            );
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted && request == _logoRequest) {
        setState(
          () => _error =
              'Не удалось прочитать логотип. Выберите другое изображение.',
        );
      }
    } finally {
      if (mounted && request == _logoRequest) {
        setState(() => _pickingLogo = false);
      }
    }
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            text.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.65,
              color: colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: DecoratedBox(
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
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.chevronColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? chevronColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? colors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
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
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: chevronColor ?? colors.muted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

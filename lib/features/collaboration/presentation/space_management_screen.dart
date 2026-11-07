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
import '../../../core/widgets/app_action_menu.dart';
import '../../../core/widgets/app_form_surface.dart';
import '../data/collaboration_models.dart';
import '../domain/collaboration_repository.dart';
import 'collaboration_cubit.dart';

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
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.error!))),
    builder: (context, state) {
      final cubit = context.read<CollaborationCubit>();
      final space = state.space;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Настройки ${cubit.kind == SpaceKind.project ? 'проекта' : 'workspace'}',
          ),
        ),
        body: space == null
            ? Center(
                child: state.loading
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: cubit.load,
                        child: const Text('Повторить загрузку'),
                      ),
              )
            : AppFormSurface(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (state.loading || state.saving)
                      const LinearProgressIndicator(minHeight: 2),
                    _SpaceFields(
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Участники · ${state.members.length}',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Добавить участника',
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
                        child: const Text('Повторить загрузку участников'),
                      ),
                    for (final member in state.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          member.name.isEmpty ? member.email : member.name,
                        ),
                        subtitle: Text(memberRoleLabel(member.role)),
                        trailing: member.role == 'OWNER'
                            ? null
                            : AppActionMenuButton<String>(
                                title: member.name,
                                tooltip: 'Действия участника',
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
                                    const AppMenuAction(
                                      value: 'remove',
                                      label: 'Удалить из участников',
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
                                      'Удалить участника?',
                                      '${member.name} потеряет доступ к этому разделу.',
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
                    const SizedBox(height: 24),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        LucideIcons.archive,
                        size: AppIconSizes.standard,
                      ),
                      title: const Text('Архивировать'),
                      onTap: state.saving
                          ? null
                          : () async {
                              if (!await showAppConfirmation(
                                context,
                                'Архивировать ${cubit.kind.label.toLowerCase()}?',
                                'Вы сможете восстановить его из архива.',
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        LucideIcons.trash2,
                        size: AppIconSizes.standard,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Удалить',
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: state.saving
                          ? null
                          : () async {
                              if (!await showAppConfirmation(
                                context,
                                'Удалить ${cubit.kind.label.toLowerCase()}?',
                                'Это действие нельзя отменить. Связанные данные могут быть удалены.',
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
        cubit.kind == SpaceKind.project
            ? state.space!.raw['workspaceId']?.toString() ?? ''
            : '',
      );
      if (!context.mounted) return;
      final available = candidates
          .where((user) => !state.members.any((m) => m.userId == user.userId))
          .toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все доступные пользователи уже добавлены.'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
  late final _code = TextEditingController(
    text: widget.space.raw['code']?.toString() ?? '',
  );
  late final _description = TextEditingController(
    text: widget.space.raw['description']?.toString() ?? '',
  );
  late final _color = TextEditingController(
    text: widget.space.raw['color']?.toString() ?? '#6D5FE0',
  );
  late final _logo = TextEditingController(
    text: widget.space.raw['logoUrl']?.toString() ?? '',
  );
  late DateTime? _start = DateTime.tryParse(
    widget.space.raw['start']?.toString() ?? '',
  );
  late DateTime? _end = DateTime.tryParse(
    widget.space.raw['end']?.toString() ?? '',
  );
  late bool _pinned = widget.space.raw['isPinned'] == true;
  bool _pickingLogo = false;
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
        label: 'Название',
        child: TextField(
          controller: _name,
          enabled: !widget.saving,
          decoration: InputDecoration(errorText: _error),
        ),
      ),
      if (widget.kind == SpaceKind.project) ...[
        const SizedBox(height: 16),
        AppFormField(
          label: 'Код проекта',
          child: TextField(controller: _code, enabled: !widget.saving),
        ),
        const SizedBox(height: 16),
        AppFormField(
          label: 'Описание',
          child: TextField(
            controller: _description,
            enabled: !widget.saving,
            minLines: 2,
            maxLines: 5,
          ),
        ),
        const SizedBox(height: 12),
        for (final isStart in [true, false])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              LucideIcons.calendar,
              size: AppIconSizes.standard,
            ),
            title: Text(isStart ? 'Начало проекта' : 'Окончание проекта'),
            subtitle: Text(_formatDate(isStart ? _start : _end)),
            onTap: widget.saving ? null : () => _pickDate(isStart),
            trailing: IconButton(
              tooltip: 'Убрать дату',
              onPressed: widget.saving
                  ? null
                  : () => setState(() {
                      if (isStart) {
                        _start = null;
                      } else {
                        _end = null;
                      }
                    }),
              icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Закрепить проект'),
          value: _pinned,
          activeTrackColor: AppColors.accent,
          onChanged: widget.saving
              ? null
              : (value) => setState(() => _pinned = value),
        ),
      ] else ...[
        const SizedBox(height: 16),
        AppFormField(
          label: 'Цвет (#RRGGBB)',
          child: TextField(controller: _color, enabled: !widget.saving),
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
                      ? 'Загрузка…'
                      : _logo.text.isEmpty
                      ? 'Добавить логотип'
                      : 'Заменить логотип',
                ),
              ),
            ),
            if (_logo.text.isNotEmpty)
              IconButton(
                tooltip: 'Убрать логотип',
                onPressed: widget.saving ? null : () => setState(_logo.clear),
                icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
              ),
          ],
        ),
      ],
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AppColors.error)),
      const SizedBox(height: 20),
      AppFormButton(
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
                if (_start != null && _end != null && _end!.isBefore(_start!)) {
                  setState(
                    () => _error = 'Окончание должно быть после начала проекта',
                  );
                  return;
                }
                setState(() => _error = null);
                await widget.onSave({
                  'name': _name.text.trim(),
                  if (widget.kind == SpaceKind.project) ...{
                    'code': _code.text.trim(),
                    'description': _description.text.trim(),
                    'isPinned': _pinned,
                    'start': _start?.toUtc().toIso8601String(),
                    'end': _end?.toUtc().toIso8601String(),
                  },
                  if (widget.kind == SpaceKind.workspace) ...{
                    'color': _color.text.trim(),
                    if (_logo.text !=
                        (widget.space.raw['logoUrl']?.toString() ?? ''))
                      'logoUrl': _logo.text.isEmpty ? null : _logo.text,
                  },
                });
              },
        child: Text(widget.saving ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
  String _formatDate(DateTime? date) => date == null
      ? 'Не указана'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        if (isStart) {
          _start = date;
        } else {
          _end = date;
        }
      });
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
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
          if (data != null && mounted) {
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
      if (mounted) {
        setState(
          () => _error =
              'Не удалось прочитать логотип. Выберите другое изображение.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }
}

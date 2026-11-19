import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_translation.dart';
import '../cubit/kanban_cubit.dart';
import 'task_card.dart';

Future<void> handleTaskCardAction(
  BuildContext context,
  ProjectTaskModel task,
  TaskCardAction action,
  String workspaceId,
) async {
  final cubit = context.read<KanbanCubit>();
  switch (action) {
    case TaskCardAction.duplicate:
      if (await cubit.duplicateTask(task) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.success,
            content: Text('Копия задачи создана'),
          ),
        );
      }
    case TaskCardAction.archive:
      await cubit.archiveTask(task);
    case TaskCardAction.delete:
      final confirmed = await showAppConfirmation(
        context,
        'Удалить задачу?',
        '«${task.title}» будет удалена. Это действие нельзя отменить.',
        confirmLabel: 'Удалить',
        destructive: true,
      );
      if (confirmed == true && context.mounted) await cubit.deleteTask(task);
    case TaskCardAction.cover:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CoverSheet(task: task, cubit: cubit),
      );
    case TaskCardAction.translate:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _TranslationSheet(
          task: task,
          cubit: cubit,
          workspaceId: workspaceId,
        ),
      );
    default:
      break;
  }
}

class _CoverSheet extends StatefulWidget {
  const _CoverSheet({required this.task, required this.cubit});
  final ProjectTaskModel task;
  final KanbanCubit cubit;
  @override
  State<_CoverSheet> createState() => _CoverSheetState();
}

class _CoverSheetState extends State<_CoverSheet> {
  Map<String, dynamic>? _cover;
  bool _busy = false;
  String? _error;
  static const _colors = [
    '#6366F1',
    '#EC4899',
    '#F59E0B',
    '#10B981',
    '#3B82F6',
    '#8B5CF6',
    '#64748B',
    '#EF4444',
  ];
  @override
  void initState() {
    super.initState();
    _cover = widget.task.cover.isEmpty
        ? null
        : Map<String, dynamic>.from(widget.task.cover);
  }

  Future<void> _pickImage() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      if ((await files.first.length() ?? 0) > 20 * 1024 * 1024) {
        throw const FormatException('Выберите изображение размером до 20 МБ.');
      }
      final codec = await ui.instantiateImageCodec(
        await files.first.readAsBytes(),
        targetWidth: 800,
        targetHeight: 450,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final bytes = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (bytes == null) {
            throw const FormatException('Не удалось прочитать изображение.');
          }
          if (mounted) {
            setState(
              () => _cover = {
                'type': 'image',
                'url':
                    'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}',
              },
            );
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Не удалось открыть изображение.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.cubit.updateCover(widget.task, _cover);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error =
            widget.cubit.state.actionErrorMessage ??
            'Не удалось сохранить обложку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Обложка задачи',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_cover != null) ...[
              TaskCover(cover: _cover!),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _colors)
                  Semantics(
                    label: 'Цвет $color',
                    selected: _cover?['color'] == color,
                    button: true,
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(
                              () => _cover = {'type': 'color', 'color': color},
                            ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse('FF${color.substring(1)}', radix: 16),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _cover?['color'] == color
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: AppIconSizes.standard,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(
                Icons.image_outlined,
                size: AppIconSizes.standard,
              ),
              label: const Text('Выбрать изображение'),
            ),
            TextButton(
              onPressed: _busy || _cover == null
                  ? null
                  : () => setState(() => _cover = null),
              child: const Text('Убрать обложку'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({
    required this.task,
    required this.cubit,
    required this.workspaceId,
  });
  final ProjectTaskModel task;
  final KanbanCubit cubit;
  final String workspaceId;
  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  String _language = 'Казахский';
  TaskTranslation? _translation;
  bool _busy = false;
  String? _error;

  Future<void> _translate() async {
    setState(() {
      _busy = true;
      _error = null;
      _translation = null;
    });
    final translation = await widget.cubit.translateTask(
      widget.task,
      widget.workspaceId,
      _language,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _translation = translation;
        if (translation == null) {
          _error =
              widget.cubit.state.actionErrorMessage ??
              'Не удалось перевести задачу.';
        }
      });
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.cubit.applyTranslation(
      widget.task,
      _translation!,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error =
            widget.cubit.state.actionErrorMessage ??
            'Не удалось сохранить перевод.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Перевести задачу',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            AppFormField(
              label: 'Язык перевода',
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _language,
                decoration: const InputDecoration(hintText: 'Язык перевода'),
                items: [
                  for (final language in ['Казахский', 'Русский', 'Английский'])
                    DropdownMenuItem(value: language, child: Text(language)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _language = value!;
                        _translation = null;
                      }),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _translate,
              child: const Text('Получить перевод'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            if (_translation != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                _translation!.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(_translation!.description),
              const SizedBox(height: 16),
              Text(
                'Применение перевода заменит название и описание задачи.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${_translation!.title}\n\n${_translation!.description}',
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              appSnackBar(
                                context: context,
                                tone: AppSnackBarTone.success,
                                content: Text('Перевод скопирован'),
                              ),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _error = 'Не удалось скопировать перевод.',
                            );
                          }
                        }
                      },
                child: const Text('Скопировать перевод'),
              ),
              FilledButton(
                onPressed: _busy ? null : _apply,
                child: const Text('Применить перевод'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

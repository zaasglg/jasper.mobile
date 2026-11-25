import 'package:forui/forui.dart';
import '../../../../core/di/service_locator.dart';
import '../../../tasks/presentation/cubit/task_details_cubit.dart';
import '../../../tasks/presentation/cubit/task_details_state.dart';
import '../../../tasks/presentation/widgets/task_extras_sheet.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_task_cover.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
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
            content: Text(tr(context, 'Копия задачи создана')),
          ),
        );
      }
    case TaskCardAction.archive:
      await cubit.archiveTask(task);
    case TaskCardAction.delete:
      final confirmed = await showAppConfirmation(
        context,
        tr(context, 'Удалить задачу?'),
        tr(context, "«{p0}» будет удалена. Это действие нельзя отменить.", {
          'p0': task.title,
        }),
        confirmLabel: 'Удалить',
        destructive: true,
      );
      if (confirmed == true && context.mounted) await cubit.deleteTask(task);
    case TaskCardAction.epics:
    case TaskCardAction.labels:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => BlocProvider(
          create: (_) =>
              sl<TaskDetailsCubit>()..load(task.id, initialTask: task),
          child: _TaskExtrasActionSheet(
            task: task,
            tab: action == TaskCardAction.epics
                ? TaskExtraTab.epics
                : TaskExtraTab.labels,
          ),
        ),
      );
      if (!cubit.isClosed) await cubit.load(task.projectId, refresh: true);
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

class _TaskExtrasActionSheet extends StatelessWidget {
  const _TaskExtrasActionSheet({required this.task, required this.tab});

  final ProjectTaskModel task;
  final TaskExtraTab tab;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
        builder: (context, state) {
          if (state.status == TaskDetailsStatus.success) {
            return TaskExtrasSheet(tab: tab);
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: state.status == TaskDetailsStatus.failure
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr(context, 'Не удалось загрузить задачу')),
                        TextButton(
                          onPressed: () => context
                              .read<TaskDetailsCubit>()
                              .load(task.id, initialTask: task),
                          child: Text(tr(context, 'Повторить')),
                        ),
                      ],
                    )
                  : const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          );
        },
      );
}

class _CoverSheet extends StatefulWidget {
  const _CoverSheet({required this.task, required this.cubit});
  final ProjectTaskModel task;
  final KanbanCubit cubit;
  @override
  State<_CoverSheet> createState() => _CoverSheetState();
}

class _CoverSheetState extends State<_CoverSheet> {
  ProjectTaskCover? _cover;
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
    _cover = widget.task.cover;
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
            final url =
                'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}';
            setState(
              () => _cover = ProjectTaskCover(
                type: 'image',
                url: url,
                displayUrl: url,
              ),
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
    final saved = await widget.cubit.updateCover(
      widget.task,
      _cover == null
          ? null
          : {
              if (_cover!.type != null) 'type': _cover!.type,
              if (_cover!.color != null) 'color': _cover!.color,
              if (_cover!.fileId != null) 'fileId': _cover!.fileId,
              if (_cover!.url != null) 'url': _cover!.url,
              if (_cover!.imageUrl != null) 'imageUrl': _cover!.imageUrl,
            },
    );
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
              tr(context, 'Обложка задачи'),
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
                    label: tr(context, "Цвет {p0}", {'p0': color}),
                    selected: _cover?.color == color,
                    button: true,
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(
                              () => _cover = ProjectTaskCover(
                                type: 'color',
                                color: color,
                              ),
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
                        child: _cover?.color == color
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
              label: Text(tr(context, 'Выбрать изображение')),
            ),
            TextButton(
              onPressed: _busy || _cover == null
                  ? null
                  : () => setState(() => _cover = null),
              child: Text(tr(context, 'Убрать обложку')),
            ),
            if (_error != null)
              Text(
                tr(context, _error!),
                style: TextStyle(color: AppColors.of(context).error),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr(context, 'Сохранить')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TranslationSheet extends StatelessWidget {
  const _TranslationSheet({
    required this.task,
    required this.cubit,
    required this.workspaceId,
  });
  final ProjectTaskModel task;
  final KanbanCubit cubit;
  final String workspaceId;

  @override
  Widget build(BuildContext context) => FTheme(
    data: Theme.of(context).brightness == Brightness.dark
        ? FTheme.neutral.dark.touch
        : FTheme.neutral.light.touch,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                tr(context, 'Язык перевода'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FItemGroup(
              children: [
                for (final language in ['Казахский', 'Русский', 'Английский'])
                  FItem(
                    title: Text(tr(context, language)),
                    suffix: const Icon(Icons.chevron_right, size: 18),
                    onPress: () {
                      Navigator.pop(context);
                      cubit.translateTask(task, workspaceId, language);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

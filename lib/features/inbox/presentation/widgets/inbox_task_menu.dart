import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/widgets/app_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../planner/presentation/screens/planner_screen.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../data/models/inbox_task_model.dart';
import '../../domain/repositories/inbox_repository.dart';
import '../cubit/inbox_cubit.dart';

Future<void> showInboxTaskCard(BuildContext context, InboxTaskModel task) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => sl<InboxCubit>(),
        child: _InboxEditor(task: task, mode: _Action.open),
      ),
    );

enum _Action {
  open('Открыть карточку', LucideIcons.panelTop),
  labels('Изменить метки', LucideIcons.tag),
  dates('Изменить даты', LucideIcons.clock),
  move('Переместить', LucideIcons.arrowRight),
  schedule('В ежедневник', LucideIcons.calendarPlus),
  copy('Копировать карточку', LucideIcons.copy),
  archive('Архивировать', LucideIcons.archive),
  delete('Удалить', LucideIcons.trash2);

  const _Action(this.label, this.icon);
  final String label;
  final IconData icon;
}

class InboxTaskMenu extends StatelessWidget {
  const InboxTaskMenu({super.key, required this.task, this.busy = false});
  final InboxTaskModel task;
  final bool busy;

  Future<void> _select(BuildContext context, _Action action) async {
    final cubit = context.read<InboxCubit>();
    Future<void> Function(InboxActionsRepository)? request;
    switch (action) {
      case _Action.open:
      case _Action.labels:
      case _Action.dates:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: _InboxEditor(task: task, mode: action),
          ),
        );
        return;
      case _Action.schedule:
        await showScheduleInboxTask(context, task);
        return;
      case _Action.copy:
        request = (repository) => repository.copyTask(task);
      case _Action.archive:
        request = (repository) =>
            repository.updateTask(task.id, {'archived': !task.archived});
      case _Action.delete:
        final confirmed = await showAppConfirmation(
          context,
          'Удалить задачу?',
          task.title,
          confirmLabel: 'Удалить',
          destructive: true,
        );
        if (confirmed != true) return;
        if (task.isLocalOnly) {
          cubit.removeLocal(task.id);
          return;
        }
        request = (repository) => repository.deleteTask(task.id);
      case _Action.move:
        final projects =
            context.read<ProjectsCubit?>()?.state.projects ?? <ProjectModel>[];
        List<ProjectModel> flatten(List<ProjectModel> values) => [
          for (final project in values) ...[
            project,
            ...flatten(project.children),
          ],
        ];
        final projectId = await showAppActionMenu<String>(
          context,
          title: 'Переместить в проект',
          groups: [
            [
              for (final project in flatten(projects))
                AppMenuAction(
                  value: project.id,
                  label: project.name,
                  icon: LucideIcons.folder,
                ),
            ],
          ],
        );
        if (projectId == null) return;
        request = (repository) => repository.moveTask(task.id, projectId);
    }
    if (cubit.isClosed) return;
    final error = await cubit.runAction(task.id, request);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Готово')));
    }
  }

  @override
  Widget build(BuildContext context) => AppActionMenuButton<_Action>(
    key: ValueKey('inbox-task-actions-${task.id}'),
    title: task.title,
    eyebrow: 'Задача в Инбоксе',
    tooltip: 'Действия задачи',
    enabled: !busy,
    onSelected: (action) => _select(context, action),
    groups: [
      for (final group in const [
        [
          _Action.open,
          _Action.labels,
          _Action.dates,
          _Action.move,
          _Action.schedule,
          _Action.copy,
        ],
        [_Action.archive, _Action.delete],
      ])
        [
          for (final action in group)
            AppMenuAction(
              value: action,
              label: action == _Action.archive && task.archived
                  ? 'Из архива'
                  : action.label,
              icon: action.icon,
              destructive: action == _Action.delete,
              muted: action == _Action.archive,
              enabled:
                  !task.isLocalOnly ||
                  action == _Action.open ||
                  action == _Action.delete,
              opensSubmenu: const {
                _Action.open,
                _Action.labels,
                _Action.dates,
                _Action.move,
                _Action.schedule,
              }.contains(action),
            ),
        ],
    ],
  );
}

class _InboxEditor extends StatefulWidget {
  const _InboxEditor({required this.task, required this.mode});
  final InboxTaskModel task;
  final _Action mode;
  @override
  State<_InboxEditor> createState() => _InboxEditorState();
}

class _InboxEditorState extends State<_InboxEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _labelText = TextEditingController();
  late List<Map<String, dynamic>> _labels;
  String? _start, _end, _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _description = TextEditingController(
      text:
          widget.task.detail['description']?.toString() ??
          widget.task.description ??
          '',
    );
    final labels = widget.task.detail['labels'];
    _labels = labels is List
        ? labels
              .whereType<Map>()
              .map((label) => Map<String, dynamic>.from(label))
              .toList()
        : [];
    _start = widget.task.start;
    _end = widget.task.end;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _labelText.dispose();
    super.dispose();
  }

  void _addLabel() {
    final text = _labelText.text.trim();
    if (text.isEmpty || _labels.any((label) => label['text'] == text)) return;
    setState(
      () => _labels.add({
        'id': 'label-${DateTime.now().microsecondsSinceEpoch}',
        'text': text,
        'color': '#6d5fe0',
      }),
    );
    _labelText.clear();
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse((start ? _start : _end) ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final value =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Введите название задачи');
      return;
    }
    if (_start != null && _end != null && _start!.compareTo(_end!) > 0) {
      setState(() => _error = 'Срок не может быть раньше начала');
      return;
    }
    _addLabel();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<InboxCubit>().runAction(
      widget.task.id,
      (repository) => repository.updateTask(widget.task.id, {
        'title': _title.text.trim(),
        'start': _start,
        'end': _end,
        'detail': {
          ...widget.task.detail,
          'description': _description.text,
          'labels': _labels,
        },
      }),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.mode == _Action.open
                ? 'Карточка Инбокса'
                : widget.mode.label,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          AppFormField(
            label: 'Название',
            child: TextField(
              controller: _title,
              readOnly: _saving || widget.task.isLocalOnly,
              decoration: const InputDecoration(hintText: 'Название'),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.mode == _Action.open) ...[
            AppFormField(
              label: 'Описание',
              child: TextField(
                controller: _description,
                readOnly: _saving || widget.task.isLocalOnly,
                decoration: const InputDecoration(hintText: 'Описание'),
                maxLines: 4,
                minLines: 2,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.mode != _Action.dates) ...[
            const Text('Метки'),
            Wrap(
              spacing: 6,
              children: [
                for (final label in _labels)
                  InputChip(
                    label: Text(label['text']?.toString() ?? ''),
                    onDeleted: _saving || widget.task.isLocalOnly
                        ? null
                        : () => setState(() => _labels.remove(label)),
                  ),
              ],
            ),
            AppFormField(
              label: 'Новая метка',
              child: TextField(
                controller: _labelText,
                enabled: !_saving && !widget.task.isLocalOnly,
                autofocus: widget.mode == _Action.labels,
                decoration: InputDecoration(
                  hintText: 'Новая метка',
                  suffixIcon: IconButton(
                    onPressed: _saving ? null : _addLabel,
                    icon: const Icon(Icons.add, size: AppIconSizes.standard),
                  ),
                ),
                onSubmitted: (_) => _addLabel(),
              ),
            ),
          ],
          if (widget.mode != _Action.labels)
            for (final start in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.calendar,
                  size: AppIconSizes.standard,
                ),
                title: Text(start ? 'Начало' : 'Срок'),
                subtitle: Text((start ? _start : _end) ?? 'Не задано'),
                onTap: _saving || widget.task.isLocalOnly
                    ? null
                    : () => _pickDate(start),
                trailing: (start ? _start : _end) == null
                    ? null
                    : IconButton(
                        tooltip: 'Убрать дату',
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                if (start) {
                                  _start = null;
                                } else {
                                  _end = null;
                                }
                              }),
                        icon: const Icon(
                          Icons.close,
                          size: AppIconSizes.standard,
                        ),
                      ),
              ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 20),
          if (!widget.task.isLocalOnly)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
            ),
        ],
      ),
    ),
  );
}

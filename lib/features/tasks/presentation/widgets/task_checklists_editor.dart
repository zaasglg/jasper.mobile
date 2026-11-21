import '../../../projects/domain/entities/task_assignee_model.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/widgets/app_action_menu.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/task_detail_model.dart';
import '../cubit/task_details_cubit.dart';

String _id() => 'check_${DateTime.now().microsecondsSinceEpoch}';

Future<String?> _askName(BuildContext context, String title, String initial) =>
    showAppDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );

Future<bool> _confirm(BuildContext context, String title) =>
    showAppConfirmation(
      context,
      title,
      'Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
    );

class TaskChecklistsEditor extends StatelessWidget {
  const TaskChecklistsEditor({
    super.key,
    required this.checklists,
    required this.enabled,
    this.showCreation = false,
    this.onCloseCreation,
  });
  final List<TaskChecklistModel> checklists;
  final bool enabled;
  final bool showCreation;
  final VoidCallback? onCloseCreation;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (showCreation)
        ChecklistQuickAdd(
          key: const ValueKey('new-checklist-inline'),
          label: 'Добавить чек-лист',
          hint: 'Название чек-листа',
          initiallyOpen: true,
          enabled: enabled,
          onClose: onCloseCreation,
          onSubmit: (name) async {
            final cubit = context.read<TaskDetailsCubit>();
            await cubit.addChecklist(name: name);
            final saved =
                !cubit.isClosed && cubit.state.actionErrorMessage == null;
            if (saved && context.mounted) onCloseCreation?.call();
            return saved;
          },
        ),
      if (checklists.isEmpty && !showCreation)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Нет чек-листов. Добавьте первый кнопкой «+».',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      for (final list in checklists)
        _ListCard(key: ValueKey(list.id), list: list, enabled: enabled),
    ],
  );
}

class _ListCard extends StatelessWidget {
  const _ListCard({super.key, required this.list, required this.enabled});
  final TaskChecklistModel list;
  final bool enabled;

  Future<void> _change(
    BuildContext context,
    TaskChecklistModel Function(TaskChecklistModel) transform,
  ) => context.read<TaskDetailsCubit>().modifyChecklist(list.id, transform);

  Future<void> _rename(
    BuildContext context, {
    TaskChecklistSectionModel? section,
  }) async {
    final cubit = context.read<TaskDetailsCubit>();
    final name = await _askName(
      context,
      section == null ? 'Название чек-листа' : 'Название раздела',
      section?.name ?? list.name,
    );
    if (name == null || cubit.isClosed) return;
    await cubit.modifyChecklist(
      list.id,
      (current) => section == null
          ? current.copyWith(name: name)
          : current.copyWith(
              sections: [
                for (final value in current.sections)
                  value.id == section.id ? value.copyWith(name: name) : value,
              ],
            ),
    );
  }

  Future<bool> _addItem(
    BuildContext context,
    String text, {
    String? sectionId,
  }) async {
    final cubit = context.read<TaskDetailsCubit>();
    final item = TaskChecklistItemModel(id: _id(), text: text);
    await cubit.modifyChecklist(
      list.id,
      (current) => sectionId == null
          ? current.copyWith(items: [...current.items, item])
          : current.copyWith(
              sections: [
                for (final section in current.sections)
                  section.id == sectionId
                      ? section.copyWith(items: [...section.items, item])
                      : section,
              ],
            ),
    );
    return !cubit.isClosed && cubit.state.actionErrorMessage == null;
  }

  Future<void> _editItem(
    BuildContext context, {
    TaskChecklistItemModel? item,
    String? sectionId,
  }) async {
    final cubit = context.read<TaskDetailsCubit>();
    final result = await showModalBottomSheet<TaskChecklistItemModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemEditor(item: item, cubit: cubit),
    );
    if (result == null || cubit.isClosed) return;
    List<TaskChecklistItemModel> change(List<TaskChecklistItemModel> values) =>
        item == null
        ? [...values, result]
        : [for (final value in values) value.id == item.id ? result : value];
    await cubit.modifyChecklist(
      list.id,
      (current) => sectionId == null
          ? current.copyWith(items: change(current.items))
          : current.copyWith(
              sections: [
                for (final section in current.sections)
                  section.id == sectionId
                      ? section.copyWith(items: change(section.items))
                      : section,
              ],
            ),
    );
  }

  Future<void> _deleteItem(BuildContext context, String itemId) async {
    final cubit = context.read<TaskDetailsCubit>();
    if (!await _confirm(context, 'Удалить пункт?') || cubit.isClosed) return;
    await cubit.modifyChecklist(
      list.id,
      (current) => current.copyWith(
        items: current.items.where((item) => item.id != itemId).toList(),
        sections: [
          for (final section in current.sections)
            section.copyWith(
              items: section.items.where((item) => item.id != itemId).toList(),
            ),
        ],
      ),
    );
  }

  List<T> _move<T>(List<T> values, int index, int direction) {
    final result = [...values];
    final target = index + direction;
    if (index < 0 || target < 0 || target >= values.length) return result;
    result.insert(target, result.removeAt(index));
    return result;
  }

  Future<void> _moveItem(
    BuildContext context,
    String itemId,
    String? sectionId,
    int direction,
  ) => _change(context, (current) {
    List<TaskChecklistItemModel> move(List<TaskChecklistItemModel> values) =>
        _move(
          values,
          values.indexWhere((item) => item.id == itemId),
          direction,
        );
    return sectionId == null
        ? current.copyWith(items: move(current.items))
        : current.copyWith(
            sections: [
              for (final section in current.sections)
                section.id == sectionId
                    ? section.copyWith(items: move(section.items))
                    : section,
            ],
          );
  });

  Widget _item(
    BuildContext context,
    TaskChecklistItemModel item,
    int index,
    int length, {
    String? sectionId,
  }) => Row(
    key: ValueKey(item.id),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Checkbox.adaptive(
        value: item.done,
        onChanged: enabled
            ? (_) => context.read<TaskDetailsCubit>().toggleChecklistItem(
                list.id,
                item.id,
              )
            : null,
        visualDensity: VisualDensity.compact,
      ),
      Expanded(
        child: InkWell(
          onTap: enabled
              ? () => _editItem(context, item: item, sectionId: sectionId)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: TextStyle(
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    color: item.done ? AppColors.muted : null,
                  ),
                ),
                if (item.dueDate != null)
                  Text(
                    '${item.dueDate!.day}.${item.dueDate!.month}.${item.dueDate!.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                if (item.assigneeIds.isNotEmpty)
                  Text(
                    item.assigneeIds
                        .map(
                          (id) =>
                              context
                                  .read<TaskDetailsCubit>()
                                  .state
                                  .task
                                  ?.assignees
                                  .where((user) => user.userId == id)
                                  .firstOrNull
                                  ?.name ??
                              'Исполнитель',
                        )
                        .join(', '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      AppActionMenuButton<String>(
        title: item.text,
        eyebrow: 'Пункт чек-листа',
        tooltip: 'Действия пункта',
        enabled: enabled,
        onSelected: (action) {
          if (action == 'edit') {
            _editItem(context, item: item, sectionId: sectionId);
          }
          if (action == 'delete') _deleteItem(context, item.id);
          if (action == 'up' || action == 'down') {
            _moveItem(context, item.id, sectionId, action == 'up' ? -1 : 1);
          }
        },
        groups: [
          [
            const AppMenuAction(
              value: 'edit',
              label: 'Редактировать',
              icon: LucideIcons.pencil,
              opensSubmenu: true,
            ),
            AppMenuAction(
              value: 'up',
              label: 'Выше',
              icon: LucideIcons.arrowUp,
              enabled: index > 0,
            ),
            AppMenuAction(
              value: 'down',
              label: 'Ниже',
              icon: LucideIcons.arrowDown,
              enabled: index < length - 1,
            ),
          ],
          const [
            AppMenuAction(
              value: 'delete',
              label: 'Удалить',
              icon: LucideIcons.trash2,
              destructive: true,
            ),
          ],
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                list.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${list.completed}/${list.total}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            AppActionMenuButton<String>(
              title: list.name,
              eyebrow: 'Чек-лист',
              tooltip: 'Действия чек-листа',
              enabled: enabled,
              onSelected: (action) async {
                final cubit = context.read<TaskDetailsCubit>();
                if (action == 'rename') {
                  await _rename(context);
                  return;
                }
                if (action == 'up' || action == 'down') {
                  await cubit.moveChecklist(list.id, action == 'up' ? -1 : 1);
                  return;
                }
                if (action == 'delete' &&
                    await _confirm(
                      context,
                      'Удалить чек-лист со всеми пунктами?',
                    ) &&
                    !cubit.isClosed) {
                  await cubit.deleteChecklist(list.id);
                }
              },
              groups: [
                [
                  const AppMenuAction(
                    value: 'rename',
                    label: 'Переименовать',
                    icon: LucideIcons.pencil,
                    opensSubmenu: true,
                  ),
                  AppMenuAction(
                    value: 'up',
                    label: 'Выше',
                    icon: LucideIcons.arrowUp,
                    enabled: true,
                  ),
                  AppMenuAction(
                    value: 'down',
                    label: 'Ниже',
                    icon: LucideIcons.arrowDown,
                    enabled: true,
                  ),
                ],
                const [
                  AppMenuAction(
                    value: 'delete',
                    label: 'Удалить чек-лист',
                    icon: LucideIcons.trash2,
                    destructive: true,
                  ),
                ],
              ],
            ),
          ],
        ),
        LinearProgressIndicator(
          value: list.progress,
          minHeight: 4,
          backgroundColor: AppColors.skeletonTrack,
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < list.items.length; i++)
          _item(context, list.items[i], i, list.items.length),
        ChecklistQuickAdd(
          key: ValueKey('add-item-${list.id}'),
          label: 'Добавить пункт',
          hint: 'Текст пункта',
          enabled: enabled,
          onSubmit: (text) => _addItem(context, text),
        ),
        for (final section in list.sections) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  section.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              AppActionMenuButton<String>(
                title: section.name,
                eyebrow: 'Раздел чек-листа',
                tooltip: 'Действия раздела',
                enabled: enabled,
                onSelected: (action) async {
                  if (action == 'rename') {
                    await _rename(context, section: section);
                    return;
                  }
                  if (action == 'up' || action == 'down') {
                    await _change(
                      context,
                      (current) => current.copyWith(
                        sections: _move(
                          current.sections,
                          current.sections.indexWhere(
                            (value) => value.id == section.id,
                          ),
                          action == 'up' ? -1 : 1,
                        ),
                      ),
                    );
                    return;
                  }
                  if (action == 'delete') {
                    final cubit = context.read<TaskDetailsCubit>();
                    if (await _confirm(
                          context,
                          'Удалить раздел со всеми пунктами?',
                        ) &&
                        !cubit.isClosed) {
                      await cubit.modifyChecklist(
                        list.id,
                        (current) => current.copyWith(
                          sections: current.sections
                              .where((value) => value.id != section.id)
                              .toList(),
                        ),
                      );
                    }
                  }
                },
                groups: [
                  [
                    const AppMenuAction(
                      value: 'rename',
                      label: 'Переименовать',
                      icon: LucideIcons.pencil,
                      opensSubmenu: true,
                    ),
                    AppMenuAction(
                      value: 'up',
                      label: 'Выше',
                      icon: LucideIcons.arrowUp,
                      enabled: true,
                    ),
                    AppMenuAction(
                      value: 'down',
                      label: 'Ниже',
                      icon: LucideIcons.arrowDown,
                      enabled: true,
                    ),
                  ],
                  const [
                    AppMenuAction(
                      value: 'delete',
                      label: 'Удалить раздел',
                      icon: LucideIcons.trash2,
                      destructive: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
          for (var i = 0; i < section.items.length; i++)
            _item(
              context,
              section.items[i],
              i,
              section.items.length,
              sectionId: section.id,
            ),
          ChecklistQuickAdd(
            key: ValueKey('add-section-item-${section.id}'),
            label: 'Добавить пункт в раздел',
            hint: 'Текст пункта',
            enabled: enabled,
            onSubmit: (text) => _addItem(context, text, sectionId: section.id),
          ),
        ],
      ],
    ),
  );
}

class ChecklistQuickAdd extends StatefulWidget {
  const ChecklistQuickAdd({
    super.key,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.onSubmit,
    this.initiallyOpen = false,
    this.onClose,
  });
  final String label, hint;
  final bool enabled, initiallyOpen;
  final Future<bool> Function(String text) onSubmit;
  final VoidCallback? onClose;
  @override
  State<ChecklistQuickAdd> createState() => _ChecklistQuickAddState();
}

class _ChecklistQuickAddState extends State<ChecklistQuickAdd> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late bool _open = widget.initiallyOpen;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !widget.enabled) return;
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Введите текст');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    bool saved;
    try {
      saved = await widget.onSubmit(text);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _text.clear();
      } else {
        _error = 'Не удалось сохранить. Попробуйте ещё раз.';
      }
    });
    if (saved) _focus.requestFocus();
  }

  void _cancel() {
    _text.clear();
    setState(() {
      _open = false;
      _error = null;
    });
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.enabled ? () => setState(() => _open = true) : null,
          icon: const Icon(Icons.add, size: AppIconSizes.standard),
          label: Text(widget.label),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('quick-add-${widget.hint}'),
                  controller: _text,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: widget.enabled && !_saving,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              IconButton(
                tooltip: 'Сохранить',
                onPressed: _saving || !widget.enabled ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.check,
                        color: AppColors.accent,
                        size: AppIconSizes.standard,
                      ),
              ),
              IconButton(
                tooltip: 'Отмена',
                onPressed: _saving ? null : _cancel,
                icon: const Icon(Icons.close, size: AppIconSizes.standard),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title, initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }
    Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.title),
    content: AppFormField(
      label: 'Название',
      child: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(hintText: 'Название', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _save, child: const Text('Сохранить')),
    ],
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({this.item, required this.cubit});
  final TaskChecklistItemModel? item;
  final TaskDetailsCubit cubit;
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.item?.text ?? '',
  );
  late DateTime? _due = widget.item?.dueDate;
  late final Set<String> _selected = {...?widget.item?.assigneeIds};
  late List<TaskAssigneeModel> _users =
      widget.cubit.state.task?.assignees ?? [];
  bool _loading = true;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await widget.cubit.getAssigneeCandidates();
      if (mounted) {
        setState(() {
          _users = {
            for (final user in [..._users, ...users]) user.userId: user,
          }.values.toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Не удалось загрузить список исполнителей';
        });
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Введите текст пункта');
      return;
    }
    Navigator.pop(
      context,
      (widget.item ?? TaskChecklistItemModel(id: _id(), text: '')).copyWith(
        text: _text.text.trim(),
        dueDate: _due,
        assigneeIds: _selected.toList(),
      ),
    );
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item == null ? 'Новый пункт' : 'Редактировать пункт',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AppFormField(
            label: 'Текст пункта',
            child: TextField(
              key: const Key('checklist-item-text'),
              controller: _text,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Текст пункта',
                errorText: _error,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.calendar_today_outlined,
              size: AppIconSizes.standard,
            ),
            title: const Text('Срок'),
            subtitle: Text(
              _due == null
                  ? 'Не задан'
                  : '${_due!.day}.${_due!.month}.${_due!.year}',
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _due ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) setState(() => _due = date);
            },
            trailing: _due == null
                ? null
                : IconButton(
                    tooltip: 'Убрать срок',
                    onPressed: () => setState(() => _due = null),
                    icon: const Icon(Icons.close, size: AppIconSizes.standard),
                  ),
          ),
          const Text(
            'Исполнители',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null)
            Text(_loadError!, style: const TextStyle(color: AppColors.muted)),
          for (final user in _users)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(user.name.isEmpty ? 'Пользователь' : user.name),
              value: _selected.contains(user.userId),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(user.userId);
                } else {
                  _selected.remove(user.userId);
                }
              }),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    ),
  );
}

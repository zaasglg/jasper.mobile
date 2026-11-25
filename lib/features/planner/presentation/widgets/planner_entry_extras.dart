import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tasks/data/models/task_detail_model.dart';
import '../../../tasks/presentation/widgets/task_checklists_editor.dart'
    show ChecklistQuickAdd;
import '../../data/models/planner_item_model.dart';
import '../../domain/repositories/task_icon_repository.dart';
import '../cubit/planner_cubit.dart';
import 'planner_task_symbol.dart';

class PlannerIconSelector extends StatefulWidget {
  const PlannerIconSelector({
    super.key,
    required this.item,
    required this.enabled,
  });
  final PlannerItemModel item;
  final bool enabled;
  @override
  State<PlannerIconSelector> createState() => _PlannerIconSelectorState();
}

class _PlannerIconSelectorState extends State<PlannerIconSelector> {
  bool _open = false;
  String? _error;
  Future<void> _select(String? icon) async {
    final cubit = context.read<PlannerCubit>();
    final saved = await cubit.updateExtras(
      widget.item,
      updateIcon: true,
      icon: icon,
    );
    if (!mounted) return;
    setState(() {
      _error = saved
          ? null
          : cubit.state.actionError ?? 'Не удалось сохранить иконку.';
      if (saved) _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final automatic = context.select(
      (PlannerCubit cubit) =>
          cubit.state.taskIcons[plannerIconTitle(widget.item.title)],
    );
    final name = widget.item.icon ?? automatic ?? 'task';
    final symbol = plannerTaskSymbol(context, widget.item);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('planner-icon-selector'),
              onTap: widget.enabled
                  ? () => setState(() => _open = !_open)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(symbol.icon, size: 22, color: symbol.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'Иконка'),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            plannerIconLabels[name] ?? 'Задача',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.item.icon == null)
                      Text(
                        tr(context, 'Авто'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Icon(
                      _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 48).floor().clamp(
                    3,
                    5,
                  );
                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final entry in plannerTaskSymbols.entries)
                        SizedBox(
                          width:
                              (constraints.maxWidth - (columns - 1) * 4) /
                              columns,
                          height: 44,
                          child: IconButton(
                            key: ValueKey('planner-icon-${entry.key}'),
                            tooltip: plannerIconLabels[entry.key],
                            isSelected: widget.item.icon == entry.key,
                            style: IconButton.styleFrom(
                              backgroundColor: widget.item.icon == entry.key
                                  ? AppColors.accent.withValues(alpha: .1)
                                  : Colors.transparent,
                            ),
                            onPressed: widget.enabled
                                ? () => _select(entry.key)
                                : null,
                            icon: Icon(
                              entry.value.icon,
                              color: entry.value.color,
                              size: 21,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            TextButton(
              key: const Key('planner-icon-auto'),
              onPressed: widget.enabled ? () => _select(null) : null,
              child: Text(tr(context, 'Подбирать автоматически')),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr(context, _error!),
                style: TextStyle(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class PlannerChecklistsPanel extends StatefulWidget {
  const PlannerChecklistsPanel({
    super.key,
    required this.item,
    required this.enabled,
  });
  final PlannerItemModel item;
  final bool enabled;
  @override
  State<PlannerChecklistsPanel> createState() => _PlannerChecklistsPanelState();
}

class _PlannerChecklistsPanelState extends State<PlannerChecklistsPanel> {
  bool _adding = false;
  String? _error;
  String _id() => 'planner_${DateTime.now().microsecondsSinceEpoch}';
  Future<bool> _save(List<TaskChecklistModel> lists) async {
    final cubit = context.read<PlannerCubit>();
    final saved = await cubit.updateExtras(widget.item, checklists: lists);
    if (mounted) {
      setState(
        () => _error = saved
            ? null
            : cubit.state.actionError ?? 'Не удалось сохранить чек-лист.',
      );
    }
    return saved;
  }

  Future<void> _delete(TaskChecklistModel list) async {
    if (await showAppConfirmation(
      context,
      tr(context, 'Удалить чек-лист?'),
      tr(context, "«{p0}» и его пункты будут удалены.", {'p0': list.name}),
      confirmLabel: 'Удалить',
      destructive: true,
    )) {
      if (mounted) {
        await _save(
          widget.item.checklists.where((entry) => entry.id != list.id).toList(),
        );
      }
    }
  }

  Future<void> _rename(TaskChecklistModel list) async {
    final name = await showAppDialog<String>(
      context: context,
      builder: (_) => _ChecklistNameDialog(initial: list.name),
    );
    if (name != null && mounted) {
      await _save([
        for (final entry in widget.item.checklists)
          entry.id == list.id ? entry.copyWith(name: name) : entry,
      ]);
    }
  }

  Future<bool> _addItem(TaskChecklistModel list, String text) => _save([
    for (final entry in widget.item.checklists)
      entry.id == list.id
          ? entry.copyWith(
              items: [
                ...entry.items,
                TaskChecklistItemModel(id: _id(), text: text),
              ],
            )
          : entry,
  ]);
  Future<void> _toggle(
    TaskChecklistModel list,
    TaskChecklistItemModel item,
    bool done,
  ) => _save([
    for (final entry in widget.item.checklists)
      entry.id == list.id
          ? entry.copyWith(
              items: [
                for (final row in entry.items)
                  row.id == item.id ? row.copyWith(done: done) : row,
              ],
              sections: [
                for (final section in entry.sections)
                  section.copyWith(
                    items: [
                      for (final row in section.items)
                        row.id == item.id ? row.copyWith(done: done) : row,
                    ],
                  ),
              ],
            )
          : entry,
  ]);
  Future<void> _editItem(
    TaskChecklistModel list,
    TaskChecklistItemModel item,
  ) async {
    final text = await showAppDialog<String>(
      context: context,
      builder: (_) =>
          _ChecklistNameDialog(initial: item.text, title: 'Текст пункта'),
    );
    if (text != null && mounted) {
      await _save([
        for (final entry in widget.item.checklists)
          entry.id == list.id
              ? entry.copyWith(
                  items: [
                    for (final row in entry.items)
                      row.id == item.id ? row.copyWith(text: text) : row,
                  ],
                  sections: [
                    for (final section in entry.sections)
                      section.copyWith(
                        items: [
                          for (final row in section.items)
                            row.id == item.id ? row.copyWith(text: text) : row,
                        ],
                      ),
                  ],
                )
              : entry,
      ]);
    }
  }

  Future<void> _deleteItem(
    TaskChecklistModel list,
    TaskChecklistItemModel item,
  ) async {
    if (!await showAppConfirmation(
          context,
          tr(context, 'Удалить пункт?'),
          item.text,
          confirmLabel: 'Удалить',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    await _save([
      for (final entry in widget.item.checklists)
        entry.id == list.id
            ? entry.copyWith(
                items: entry.items.where((row) => row.id != item.id).toList(),
                sections: [
                  for (final section in entry.sections)
                    section.copyWith(
                      items: section.items
                          .where((row) => row.id != item.id)
                          .toList(),
                    ),
                ],
              )
            : entry,
    ]);
  }

  Widget _item(TaskChecklistModel list, TaskChecklistItemModel item) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: ValueKey('planner-check-${item.id}'),
          value: item.done,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: .355),
            width: 1.4,
          ),
          onChanged: widget.enabled
              ? (value) => _toggle(list, item, value ?? false)
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                decoration: item.done ? TextDecoration.lineThrough : null,
                color: item.done
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          enabled: widget.enabled,
          tooltip: tr(context, 'Действия пункта'),
          icon: Icon(
            LucideIcons.ellipsis,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onSelected: (action) => action == 'delete'
              ? _deleteItem(list, item)
              : _editItem(list, item),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(tr(context, 'Изменить пункт')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(tr(context, 'Удалить пункт')),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final lists = widget.item.checklists;
    final total = lists.fold<int>(0, (sum, list) => sum + list.total);
    final done = lists.fold<int>(0, (sum, list) => sum + list.completed);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.listChecks,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(context, 'Чек-листы'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$done/$total',
              key: const Key('planner-checklist-count'),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        for (final list in lists)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .35),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            list.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: widget.enabled,
                          tooltip: tr(context, 'Действия чек-листа'),
                          icon: Icon(
                            LucideIcons.ellipsis,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          onSelected: (action) => action == 'delete'
                              ? _delete(list)
                              : _rename(list),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(tr(context, 'Переименовать')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(tr(context, 'Удалить')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  for (final item in list.items) _item(list, item),
                  for (final section in list.sections) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        section.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final item in section.items) _item(list, item),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: ChecklistQuickAdd(
                      key: ValueKey('planner-add-item-${list.id}'),
                      compact: true,
                      label: tr(context, 'Добавить пункт'),
                      hint: tr(context, 'Текст пункта'),
                      enabled: widget.enabled,
                      onSubmit: (text) => _addItem(list, text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_adding)
          ChecklistQuickAdd(
            key: const Key('planner-new-checklist'),
            compact: true,
            label: tr(context, 'Добавить чек-лист'),
            hint: tr(context, 'Название чек-листа'),
            initiallyOpen: true,
            enabled: widget.enabled,
            onClose: () => setState(() => _adding = false),
            onSubmit: (name) async {
              final saved = await _save([
                ...widget.item.checklists,
                TaskChecklistModel(id: _id(), name: name),
              ]);
              if (saved && mounted) setState(() => _adding = false);
              return saved;
            },
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('planner-add-checklist'),
              onPressed: widget.enabled
                  ? () => setState(() => _adding = true)
                  : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(tr(context, 'Добавить чек-лист')),
            ),
          ),
        if (_error != null)
          Text(
            tr(context, _error!),
            key: const Key('planner-checklist-error'),
            style: TextStyle(color: colors.error),
          ),
      ],
    );
  }
}

class _ChecklistNameDialog extends StatefulWidget {
  const _ChecklistNameDialog({
    required this.initial,
    this.title = 'Название чек-листа',
  });
  final String initial;
  final String title;
  @override
  State<_ChecklistNameDialog> createState() => _ChecklistNameDialogState();
}

class _ChecklistNameDialogState extends State<_ChecklistNameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(tr(context, widget.title)),
    content: TextField(
      controller: _text,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Отмена')),
      ),
      TextButton(onPressed: _save, child: Text(tr(context, 'Сохранить'))),
    ],
  );
}

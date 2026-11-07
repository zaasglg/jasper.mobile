import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../data/models/task_creation_models.dart';
import '../../data/services/task_file_picker.dart';
import '../../domain/repositories/task_details_repository.dart';
import '../cubit/task_creation_cubit.dart';

class TaskCreationScreen extends StatefulWidget {
  const TaskCreationScreen({super.key});
  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final _title = TextEditingController();
  final _days = TextEditingController(),
      _hours = TextEditingController(),
      _minutes = TextEditingController();
  bool _picking = false;
  String? _fileError;
  TaskCreationCubit get cubit => context.read<TaskCreationCubit>();
  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<Set<String>?> _choose(
    String title,
    List<(String, String)> values,
    List<String> current,
  ) async {
    final selected = current.toSet();
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => FractionallySizedBox(
          heightFactor: .7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: values.isEmpty
                    ? const Center(child: Text('Нет доступных вариантов'))
                    : ListView(
                        children: [
                          for (final value in values)
                            CheckboxListTile(
                              title: Text(
                                value.$2,
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: selected.contains(value.$1),
                              onChanged: (checked) => setState(
                                () => checked == true
                                    ? selected.add(value.$1)
                                    : selected.remove(value.$1),
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: AppFormButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Готово'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _epics() async {
    final revisionProject = cubit.state.draft.projectId;
    final values = await _choose(
      'Эпики',
      cubit.state.options.epics.map((e) => (e.id, e.name)).toList(),
      cubit.state.draft.epicIds,
    );
    if (mounted &&
        values != null &&
        cubit.state.draft.projectId == revisionProject) {
      cubit.change(cubit.state.draft.copyWith(epicIds: values.toList()));
    }
  }

  Future<void> _members() async {
    final workspace = cubit.state.draft.workspaceId;
    final values = await _choose(
      'Участники',
      cubit.state.options.members.map((e) => (e.userId, e.name)).toList(),
      cubit.state.draft.assigneeIds,
    );
    if (mounted &&
        values != null &&
        cubit.state.draft.workspaceId == workspace) {
      cubit.change(cubit.state.draft.copyWith(assigneeIds: values.toList()));
    }
  }

  Future<void> _deadline() async {
    final old = cubit.state.draft.end;
    final date = await showDatePicker(
      context: context,
      initialDate: old ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: old == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(old),
    );
    if (mounted) {
      cubit.change(
        cubit.state.draft.copyWith(
          end: DateTime(
            date.year,
            date.month,
            date.day,
            time?.hour ?? 23,
            time?.minute ?? 59,
          ),
        ),
      );
    }
  }

  void _estimate() {
    final days = int.tryParse(_days.text) ?? 0,
        hours = int.tryParse(_hours.text) ?? 0,
        minutes = int.tryParse(_minutes.text) ?? 0;
    cubit.change(
      cubit.state.draft.copyWith(
        estimateMinutes: days * 8 * 60 + hours * 60 + minutes,
      ),
    );
  }

  Future<void> _files() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final files = await TaskFilePicker.pick(
        author: cubit.state.catalog?.user.name,
        authorId: cubit.state.catalog?.user.id,
      );
      if (mounted) cubit.addFiles(files);
    } catch (error) {
      if (mounted) {
        setState(
          () => _fileError = error is TaskDetailsException
              ? error.message
              : 'Не удалось прочитать файлы',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final result = await cubit.submit();
    if (mounted && result != null) context.pop<TaskCreationResult>(result);
  }

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: AppFormField(label: label, child: child),
  );
  Widget _selectButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    Widget? trailing,
    Key? key,
  }) => Material(
    color: AppColors.subtleSurface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TaskCreationCubit, TaskCreationState>(
    builder: (context, state) {
      final busy = state.submitting;
      final draft = state.draft;
      final ready =
          !state.loadingProjects &&
          !state.loadingOptions &&
          draft.projectId.isNotEmpty;
      final epicNames = state.options.epics
          .where((e) => draft.epicIds.contains(e.id))
          .map((e) => e.name)
          .join(', ');
      final memberNames = state.options.members
          .where((e) => draft.assigneeIds.contains(e.userId))
          .map((e) => e.name)
          .join(', ');
      return PopScope(
        canPop: !busy,
        child: AppFormSurface(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text(
                'Добавить задачу',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              leading: IconButton(
                tooltip: 'Отмена',
                onPressed: busy ? null : context.pop,
                icon: const Icon(LucideIcons.x, size: 18),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (state.loading ||
                      state.loadingProjects ||
                      state.loadingOptions ||
                      busy)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        _field(
                          'Название *',
                          TextField(
                            key: const Key('create-task-title'),
                            controller: _title,
                            enabled: !busy,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Название задачи',
                            ),
                            onChanged: (value) => cubit.change(
                              cubit.state.draft.copyWith(title: value),
                            ),
                          ),
                        ),
                        if (state.catalog != null &&
                            state.catalog!.workspaces.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Нет доступных workspace',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        _field(
                          'Воркспейс',
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'create-task-workspace-${draft.workspaceId}',
                            ),
                            initialValue: draft.workspaceId.isEmpty
                                ? null
                                : draft.workspaceId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Выберите workspace',
                            ),
                            items: [
                              for (final workspace
                                  in state.catalog?.workspaces ?? [])
                                DropdownMenuItem(
                                  value: workspace.id,
                                  child: Text(
                                    workspace.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: busy || state.loading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      cubit.selectWorkspace(value);
                                    }
                                  },
                          ),
                        ),
                        _field(
                          'Проект *',
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'create-task-project-${draft.workspaceId}-${draft.projectId}',
                            ),
                            initialValue: draft.projectId.isEmpty
                                ? null
                                : draft.projectId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText:
                                  state.projects.isEmpty &&
                                      !state.loadingProjects
                                  ? 'Нет доступных проектов'
                                  : 'Выберите проект',
                            ),
                            items: [
                              for (final project in state.projects)
                                DropdownMenuItem(
                                  value: project.id,
                                  child: Text(
                                    project.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                busy || state.loadingProjects || state.loading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      cubit.selectProject(value);
                                    }
                                  },
                          ),
                        ),
                        _field(
                          'Колонка *',
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'create-task-column-${draft.projectId}-${draft.status}',
                            ),
                            initialValue: draft.status.isEmpty
                                ? null
                                : draft.status,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: draft.projectId.isEmpty
                                  ? 'Сначала выберите проект'
                                  : state.loadingOptions
                                  ? 'Загрузка колонок…'
                                  : 'Выберите колонку',
                            ),
                            items: [
                              for (final column in state.options.columns)
                                DropdownMenuItem(
                                  value: column.statusMap,
                                  child: Text(
                                    column.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: busy || !ready
                                ? null
                                : (value) {
                                    if (value != null) {
                                      cubit.selectColumn(value);
                                    }
                                  },
                          ),
                        ),
                        if (ready && state.options.columns.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'В проекте нет активных колонок. Создайте колонку в проекте.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        _field(
                          'Порядок в колонке',
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'create-task-order-${draft.status}-${draft.position}-${state.siblings.length}',
                            ),
                            initialValue: draft.position.clamp(
                              1,
                              state.siblings.length + 1,
                            ),
                            isExpanded: true,
                            items: [
                              for (
                                var i = 1;
                                i <= state.siblings.length + 1;
                                i++
                              )
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    i == state.siblings.length + 1
                                        ? '$i (в конец)'
                                        : '$i',
                                  ),
                                ),
                            ],
                            onChanged: busy || !ready || draft.status.isEmpty
                                ? null
                                : (value) {
                                    if (value != null) {
                                      cubit.change(
                                        cubit.state.draft.copyWith(
                                          position: value,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        _field(
                          'Эпик',
                          _selectButton(
                            key: const Key('create-task-epics'),
                            text: epicNames.isEmpty
                                ? 'Выберите эпики'
                                : epicNames,
                            icon: LucideIcons.layers,
                            onTap: busy || !ready ? null : _epics,
                            trailing: const Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        _field(
                          'Срок · необязательно',
                          _selectButton(
                            key: const Key('create-task-end'),
                            text: draft.end == null
                                ? 'Без срока'
                                : '${draft.end!.day}.${draft.end!.month}.${draft.end!.year} ${draft.end!.hour.toString().padLeft(2, '0')}:${draft.end!.minute.toString().padLeft(2, '0')}',
                            icon: LucideIcons.calendarClock,
                            onTap: busy ? null : _deadline,
                            trailing: draft.end == null
                                ? const Icon(
                                    LucideIcons.pencil,
                                    size: 16,
                                    color: AppColors.muted,
                                  )
                                : IconButton(
                                    tooltip: 'Убрать срок',
                                    onPressed: busy
                                        ? null
                                        : () => cubit.change(
                                            cubit.state.draft.copyWith(
                                              clearEnd: true,
                                            ),
                                          ),
                                    icon: const Icon(LucideIcons.x, size: 16),
                                  ),
                          ),
                        ),
                        _field(
                          'Приоритет',
                          DropdownButtonFormField<String>(
                            initialValue: draft.priority,
                            items: const [
                              DropdownMenuItem(
                                value: 'LOW',
                                child: Text('Низкий'),
                              ),
                              DropdownMenuItem(
                                value: 'MED',
                                child: Text('Средний'),
                              ),
                              DropdownMenuItem(
                                value: 'HIGH',
                                child: Text('Высокий'),
                              ),
                            ],
                            onChanged: busy
                                ? null
                                : (value) => cubit.change(
                                    cubit.state.draft.copyWith(
                                      priority: value ?? 'MED',
                                    ),
                                  ),
                          ),
                        ),
                        _field(
                          'Тайминг · необязательно',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const Key('create-task-days'),
                                      controller: _days,
                                      enabled: !busy,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '0',
                                        suffixText: 'дн',
                                      ),
                                      onChanged: (_) => _estimate(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('create-task-hours'),
                                      controller: _hours,
                                      enabled: !busy,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '0',
                                        suffixText: 'ч',
                                      ),
                                      onChanged: (_) => _estimate(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('create-task-minutes'),
                                      controller: _minutes,
                                      enabled: !busy,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '0',
                                        suffixText: 'мин',
                                      ),
                                      onChanged: (_) => _estimate(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Рабочий день — 8 часов',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _field(
                          'Участники',
                          _selectButton(
                            key: const Key('create-task-members'),
                            text: memberNames.isEmpty
                                ? 'Выберите участников'
                                : memberNames,
                            icon: LucideIcons.users,
                            onTap: busy || !ready ? null : _members,
                            trailing: const Icon(
                              LucideIcons.plus,
                              size: 16,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        _field(
                          'Вложения · необязательно',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final file in draft.files)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    LucideIcons.file,
                                    size: 16,
                                  ),
                                  title: Text(
                                    file.name,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Убрать файл',
                                    onPressed: busy
                                        ? null
                                        : () => cubit.change(
                                            cubit.state.draft.copyWith(
                                              files: draft.files
                                                  .where((e) => e.id != file.id)
                                                  .toList(),
                                            ),
                                          ),
                                    icon: const Icon(LucideIcons.x, size: 16),
                                  ),
                                ),
                              TextButton.icon(
                                key: const Key('create-task-files'),
                                onPressed: busy || _picking ? null : _files,
                                icon: const Icon(
                                  LucideIcons.paperclip,
                                  size: 16,
                                ),
                                label: Text(
                                  _picking
                                      ? 'Подготовка файлов…'
                                      : 'Прикрепить файлы',
                                ),
                              ),
                              const Text(
                                'До 10 МБ на файл, до 35 МБ всего',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                              if (_fileError != null)
                                Text(
                                  _fileError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!busy &&
                            state.error != null &&
                            state.catalog == null)
                          TextButton(
                            onPressed: () => cubit.initialize(),
                            child: const Text('Повторить загрузку'),
                          ),
                        if (!busy &&
                            state.error != null &&
                            state.draft.workspaceId.isNotEmpty &&
                            state.projects.isEmpty)
                          TextButton(
                            onPressed: () =>
                                cubit.selectWorkspace(state.draft.workspaceId),
                            child: const Text('Повторить загрузку проектов'),
                          ),
                        if (!busy &&
                            state.error != null &&
                            state.draft.projectId.isNotEmpty &&
                            state.options.columns.isEmpty)
                          TextButton(
                            onPressed: () =>
                                cubit.selectProject(state.draft.projectId),
                            child: const Text('Повторить загрузку параметров'),
                          ),
                      ],
                    ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        state.error!,
                        key: const Key('create-task-error'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: AppFormButton(
                        key: const Key('create-task-submit'),
                        onPressed: state.canSubmit && !_picking
                            ? _submit
                            : null,
                        child: Text(busy ? 'Создание…' : 'Добавить задачу'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

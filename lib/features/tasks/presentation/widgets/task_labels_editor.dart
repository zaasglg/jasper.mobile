import '../../data/models/task_label_dto.dart';
import '../../domain/utils/task_label_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/theme/task_label_color.dart';
import '../../../../core/widgets/app_color_picker.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../domain/entities/task_label_model.dart';
import '../cubit/task_details_cubit.dart';
import '../cubit/task_details_state.dart';

typedef _LabelCatalog = ({
  List<TaskLabelModel> shared,
  List<TaskLabelModel> personal,
});

/// Selection and creation share one bottom-sheet route and one modal barrier.
class TaskLabelsEditor extends StatefulWidget {
  const TaskLabelsEditor({super.key});
  @override
  State<TaskLabelsEditor> createState() => _TaskLabelsEditorState();
}

class _TaskLabelsEditorState extends State<TaskLabelsEditor> {
  late Future<_LabelCatalog> _future;
  final _name = TextEditingController();
  String _color = '#6D5FE0';
  String? _error;
  bool? _personalForm;
  TaskLabelModel? _editing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<TaskDetailsCubit>().getLabelCatalog();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<TaskLabelModel> _catalog(_LabelCatalog remote, bool personal) {
    final cubit = context.read<TaskDetailsCubit>();
    final raw = cubit.state.detail.raw;
    final stored = personal ? raw['personalLabelCatalog'] : raw['labelCatalog'];
    final values = personal && stored is Map
        ? stored[cubit.state.currentUser?.id]
        : stored;
    return uniqueTaskLabels([
      ...cubit.labelsForScope(personal),
      if (values is List)
        ...values.whereType<Map>().map(
          (e) => TaskLabelDto.fromJson(Map<String, dynamic>.from(e)).toEntity(),
        ),
      ...(personal ? remote.personal : remote.shared),
    ]);
  }

  void _openForm(bool personal, [TaskLabelModel? label]) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _personalForm = personal;
      _editing = label;
      _name.text = label?.text ?? '';
      _color = label?.color ?? '#6D5FE0';
      _error = null;
    });
  }

  void _back() {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _personalForm = null;
      _editing = null;
      _error = null;
    });
  }

  Future<void> _save(_LabelCatalog remote) async {
    final cubit = context.read<TaskDetailsCubit>();
    if (_saving || cubit.state.isSaving) return;
    final personal = _personalForm!;
    final text = _name.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }
    final catalog = _catalog(remote, personal);
    final oldKey = _editing == null ? null : taskLabelKey(_editing!.text);
    final key = taskLabelKey(text);
    if (catalog.any(
      (e) => taskLabelKey(e.text) == key && taskLabelKey(e.text) != oldKey,
    )) {
      setState(
        () => _error =
            'Метка с таким названием уже существует. Выберите её в списке.',
      );
      return;
    }
    final label =
        (_editing ??
                TaskLabelModel(
                  id: '${personal ? 'plabel' : 'label'}_${DateTime.now().microsecondsSinceEpoch}',
                  text: text,
                ))
            .copyWith(text: text, color: _color);
    final selected = cubit.labelsForScope(personal);
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await cubit.saveScopedLabels(
      [...selected.where((e) => taskLabelKey(e.text) != oldKey), label],
      personal: personal,
      catalog: [...catalog.where((e) => taskLabelKey(e.text) != oldKey), label],
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _personalForm = null;
        _editing = null;
        _future = Future.value((
          shared: personal
              ? remote.shared
              : [
                  ...catalog.where((e) => taskLabelKey(e.text) != oldKey),
                  label,
                ],
          personal: personal
              ? [...catalog.where((e) => taskLabelKey(e.text) != oldKey), label]
              : remote.personal,
        ));
      } else {
        _error =
            cubit.state.actionErrorMessage ??
            'Не удалось сохранить метку. Повторите попытку.';
      }
    });
    if (saved) FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
    builder: (context, state) => PopScope(
      canPop: _personalForm == null && !_saving && !state.isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _personalForm != null) _back();
      },
      child: FutureBuilder<_LabelCatalog>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                heightFactor: 1,
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Не удалось загрузить метки.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _future = context
                          .read<TaskDetailsCubit>()
                          .getLabelCatalog();
                    }),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          final remote = snapshot.data!;
          final busy = state.isSaving || _saving;
          if (_personalForm != null) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Назад к меткам',
                        onPressed: busy ? null : _back,
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                      Expanded(
                        child: Text(
                          _editing == null ? 'Новая метка' : 'Изменить метку',
                          style: AppTypography.title(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _personalForm! ? 'Личная метка' : 'Метка проекта',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.smMd),
                  AppFormField(
                    label: 'Название',
                    child: TextField(
                      key: const Key('label_name'),
                      controller: _name,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        errorText: _error,
                        errorMaxLines: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormField(
                    label: 'Цвет',
                    child: AppColorPicker(
                      value: _color,
                      enabled: !busy,
                      onChanged: (value) => setState(() => _color = value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OverflowBar(
                    spacing: AppSpacing.sm,
                    overflowSpacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: busy ? null : _back,
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: busy ? null : () => _save(remote),
                        child: Text(busy ? 'Сохранение…' : 'Сохранить'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          final cubit = context.read<TaskDetailsCubit>();
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            children: [
              for (final personal in [false, true]) ...[
                Text(
                  personal ? 'Личные метки' : 'Метки проекта',
                  style: AppTypography.title(context),
                ),
                if (personal && (state.currentUser?.id.isEmpty ?? true))
                  const Text(
                    'Не удалось определить текущего пользователя. Откройте задачу повторно.',
                  )
                else ...[
                  if (_catalog(remote, personal).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text('Нет меток. Создайте новую.'),
                    ),
                  for (final label in _catalog(remote, personal))
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(label.text),
                            secondary: Container(
                              width: AppSpacing.md,
                              height: AppSpacing.md,
                              decoration: BoxDecoration(
                                color: taskLabelColor(label.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            value: cubit
                                .labelsForScope(personal)
                                .any(
                                  (e) =>
                                      taskLabelKey(e.text) ==
                                      taskLabelKey(label.text),
                                ),
                            onChanged: busy
                                ? null
                                : (selected) async {
                                    final current = cubit.labelsForScope(
                                      personal,
                                    );
                                    await cubit.saveScopedLabels(
                                      [
                                        ...current.where(
                                          (e) =>
                                              taskLabelKey(e.text) !=
                                              taskLabelKey(label.text),
                                        ),
                                        if (selected == true) label,
                                      ],
                                      personal: personal,
                                      catalog: _catalog(remote, personal),
                                    );
                                  },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Изменить метку',
                          onPressed: busy
                              ? null
                              : () => _openForm(personal, label),
                          icon: const Icon(LucideIcons.pencil, size: 20),
                        ),
                      ],
                    ),
                  TextButton.icon(
                    key: ValueKey(
                      personal
                          ? 'create_personal_label'
                          : 'create_project_label',
                    ),
                    onPressed: busy ? null : () => _openForm(personal),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Добавить метку'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    ),
  );
}

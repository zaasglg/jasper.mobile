import '../../data/services/task_file_picker.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../domain/repositories/task_details_repository.dart';
import '../../../projects/data/models/project_task_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../data/models/task_detail_model.dart';
import '../cubit/task_details_cubit.dart';
import '../cubit/task_details_state.dart';

enum TaskExtraTab { labels, epics, resources, files }

Future<void> showTaskExtras(BuildContext context, TaskExtraTab tab) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskDetailsCubit>(),
        child: TaskExtrasSheet(tab: tab),
      ),
    );

class TaskExtrasSheet extends StatefulWidget {
  const TaskExtrasSheet({required this.tab, super.key});
  final TaskExtraTab tab;
  @override
  State<TaskExtrasSheet> createState() => _TaskExtrasSheetState();
}

class _TaskExtrasSheetState extends State<TaskExtrasSheet> {
  bool _picking = false;
  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
    builder: (context, state) {
      final cubit = context.read<TaskDetailsCubit>();
      final busy = state.isSaving || _picking;
      return AppFormSurface(
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          switch (widget.tab) {
                            TaskExtraTab.labels => 'Метки',
                            TaskExtraTab.epics => 'Эпики',
                            TaskExtraTab.resources => 'Ресурсы',
                            TaskExtraTab.files => 'Файлы',
                          },
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          LucideIcons.x,
                          size: AppIconSizes.standard,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy) const LinearProgressIndicator(minHeight: 2),
                if (state.actionErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      state.actionErrorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Expanded(
                  child: switch (widget.tab) {
                    TaskExtraTab.labels => _labels(state, cubit, busy),
                    TaskExtraTab.epics => _EpicsEditor(),
                    TaskExtraTab.resources => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final resource in state.resources)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(resource.name),
                            subtitle: Text(
                              'План: ${resource.planValue} · Факт: ${resource.factValue}',
                            ),
                            onTap: busy
                                ? null
                                : () => _editResource(cubit, resource),
                            trailing: IconButton(
                              tooltip: 'Удалить ресурс',
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await showAppConfirmation(
                                        context,
                                        'Удалить ресурс?',
                                        resource.name,
                                        confirmLabel: 'Удалить',
                                        destructive: true,
                                      )) {
                                        await cubit.deleteResource(resource.id);
                                      }
                                    },
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: AppIconSizes.standard,
                              ),
                            ),
                          ),
                        if (state.resources.isEmpty) const Text('Нет ресурсов'),
                        TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => _editResource(cubit, null),
                          icon: const Icon(
                            LucideIcons.plus,
                            size: AppIconSizes.standard,
                          ),
                          label: const Text('Добавить ресурс'),
                        ),
                      ],
                    ),
                    TaskExtraTab.files => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final file in state.detail.files)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(file.name),
                            subtitle: Text('${(file.size / 1024).ceil()} КБ'),
                            leading: const Icon(
                              LucideIcons.paperclip,
                              size: AppIconSizes.standard,
                            ),
                            onTap: () => _download(file),
                            trailing: IconButton(
                              tooltip: 'Удалить файл',
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await showAppConfirmation(
                                        context,
                                        'Удалить файл?',
                                        file.name,
                                        confirmLabel: 'Удалить',
                                        destructive: true,
                                      )) {
                                        await cubit.removeFile(file.id);
                                      }
                                    },
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: AppIconSizes.standard,
                              ),
                            ),
                          ),
                        if (state.detail.files.isEmpty)
                          const Text('Нет файлов'),
                        TextButton.icon(
                          onPressed: busy ? null : () => _pickFiles(cubit),
                          icon: const Icon(
                            LucideIcons.plus,
                            size: AppIconSizes.standard,
                          ),
                          label: const Text('Добавить файлы'),
                        ),
                      ],
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _labels(TaskDetailsState state, TaskDetailsCubit cubit, bool busy) {
    final raw = state.detail.raw['personalLabels'];
    final userId = state.currentUser?.id;
    final personalMap = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final personalRaw = personalMap[userId];
    final personal = personalRaw is List
        ? personalRaw
              .whereType<Map>()
              .map(
                (e) => TaskLabelModel.fromJson(
                  Map<String, dynamic>.from(e),
                ).copyWith(isPersonal: true),
              )
              .toList()
        : <TaskLabelModel>[];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final isPersonal in [false, true]) ...[
          Text(
            isPersonal ? 'Личные метки' : 'Метки проекта',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final label in isPersonal ? personal : state.detail.labels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label.text),
              onTap: busy ? null : () => _editLabel(cubit, label, isPersonal),
              trailing: IconButton(
                tooltip: 'Убрать метку',
                onPressed: busy
                    ? null
                    : () => isPersonal
                          ? cubit.updatePersonalLabels(
                              personal.where((e) => e.id != label.id).toList(),
                            )
                          : cubit.updateLabels(
                              state.detail.labels
                                  .where((e) => e.id != label.id)
                                  .toList(),
                            ),
                icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
              ),
            ),
          TextButton.icon(
            onPressed: busy || (isPersonal && userId == null)
                ? null
                : () => _editLabel(cubit, null, isPersonal),
            icon: const Icon(LucideIcons.plus, size: AppIconSizes.standard),
            label: const Text('Добавить метку'),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _editLabel(
    TaskDetailsCubit cubit,
    TaskLabelModel? label,
    bool personal,
  ) async {
    final result = await showAppDialog<List<String>>(
      context: context,
      builder: (_) => _ValuesDialog(
        title: label == null ? 'Новая метка' : 'Изменить метку',
        labels: const ['Название', 'Цвет (#RRGGBB)'],
        values: [label?.text ?? '', label?.color ?? '#6D5FE0'],
        colorField: true,
      ),
    );
    if (result == null || cubit.isClosed) return;
    final updated =
        (label ??
                TaskLabelModel(
                  id: 'label_${DateTime.now().microsecondsSinceEpoch}',
                  text: '',
                ))
            .copyWith(text: result[0], color: result[1]);
    final raw = cubit.state.detail.raw['personalLabels'];
    final currentRaw = raw is Map ? raw[cubit.state.currentUser?.id] : null;
    final current = personal
        ? currentRaw is List
              ? currentRaw
                    .whereType<Map>()
                    .map(
                      (e) =>
                          TaskLabelModel.fromJson(Map<String, dynamic>.from(e)),
                    )
                    .toList()
              : <TaskLabelModel>[]
        : cubit.state.detail.labels;
    final labels = [...current.where((e) => e.id != updated.id), updated];
    if (personal) {
      await cubit.updatePersonalLabels(labels);
    } else {
      await cubit.updateLabels(labels);
    }
  }

  Future<void> _editResource(
    TaskDetailsCubit cubit,
    TaskResourceModel? resource,
  ) async {
    final result = await showAppDialog<List<String>>(
      context: context,
      builder: (_) => _ValuesDialog(
        title: resource == null ? 'Новый ресурс' : 'Изменить ресурс',
        labels: const ['Название', 'План', 'Факт'],
        values: [
          resource?.name ?? '',
          '${resource?.planValue ?? 0}',
          '${resource?.factValue ?? 0}',
        ],
        numericFields: true,
      ),
    );
    if (result == null || cubit.isClosed) return;
    await cubit.saveResource(
      TaskResourceModel(
        id: resource?.id ?? '',
        name: result[0],
        planValue: double.parse(result[1].replaceAll(',', '.')),
        factValue: double.parse(result[2].replaceAll(',', '.')),
        order: resource?.order ?? cubit.state.resources.length,
      ),
      create: resource == null,
    );
  }

  Future<void> _pickFiles(TaskDetailsCubit cubit) async {
    setState(() => _picking = true);
    try {
      final files = await TaskFilePicker.pick(
        author: cubit.state.currentUser?.name,
        authorId: cubit.state.currentUser?.id,
      );
      if (files.isEmpty || cubit.isClosed) return;
      await cubit.addFiles(files);
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['https', 'http'].contains(uri.scheme)) {
      throw const TaskDetailsException('Некорректная ссылка файла.');
    }
    // Signed storage URLs must be fetched without the application's bearer token.
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    try {
      final response = await client.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? []);
    } finally {
      client.close();
    }
  }

  Future<void> _download(TaskFileModel file) async {
    try {
      final url = file.dataUrl;
      if (url == null) {
        throw const TaskDetailsException(
          'Файл не содержит данных для скачивания.',
        );
      }
      await FilePicker.saveFile(
        fileName: file.name,
        bytes: url.startsWith('data:')
            ? UriData.parse(url).contentAsBytes()
            : await _downloadBytes(url),
        mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
      );
    } catch (e) {
      _error(e);
    }
  }
}

class _EpicsEditor extends StatefulWidget {
  @override
  State<_EpicsEditor> createState() => _EpicsEditorState();
}

class _EpicsEditorState extends State<_EpicsEditor> {
  late Future<List<TaskEpicModel>> _future;
  @override
  void initState() {
    super.initState();
    _future = context.read<TaskDetailsCubit>().getEpics();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TaskEpicModel>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(
              () => _future = context.read<TaskDetailsCubit>().getEpics(),
            ),
            child: const Text('Повторить загрузку эпиков'),
          ),
        );
      }
      final cubit = context.read<TaskDetailsCubit>();
      final ids = cubit.state.task!.epics.map((e) => e.id).toSet();
      if (snapshot.data!.isEmpty) {
        return const Center(child: Text('В проекте нет эпиков'));
      }
      return ListView(
        children: [
          for (final epic in snapshot.data!)
            CheckboxListTile(
              title: Text(epic.name),
              value: ids.contains(epic.id),
              onChanged: cubit.state.isSaving
                  ? null
                  : (value) {
                      final updated = {...ids};
                      if (value == true) {
                        updated.add(epic.id);
                      } else {
                        updated.remove(epic.id);
                      }
                      cubit.updateEpics(updated.toList());
                    },
            ),
        ],
      );
    },
  );
}

class _ValuesDialog extends StatefulWidget {
  const _ValuesDialog({
    required this.title,
    required this.labels,
    required this.values,
    this.numericFields = false,
    this.colorField = false,
  });
  final String title;
  final List<String> labels, values;
  final bool numericFields, colorField;
  @override
  State<_ValuesDialog> createState() => _ValuesDialogState();
}

class _ValuesDialogState extends State<_ValuesDialog> {
  late final _controllers = widget.values
      .map((e) => TextEditingController(text: e))
      .toList();
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.title),
    content: AppFormSurface(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppFormField(
                  label: widget.labels[i],
                  child: TextField(
                    controller: _controllers[i],
                    keyboardType: widget.numericFields && i > 0
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                  ),
                ),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: () {
          final values = _controllers.map((e) => e.text.trim()).toList();
          if (values.first.isEmpty) {
            setState(() => _error = 'Введите название');
            return;
          }
          if (widget.colorField &&
              !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(values[1])) {
            setState(() => _error = 'Укажите цвет в формате #RRGGBB');
            return;
          }
          if (widget.numericFields &&
              values.skip(1).any((e) {
                final n = double.tryParse(e.replaceAll(',', '.'));
                return n == null || !n.isFinite || n < 0;
              })) {
            setState(() => _error = 'План и факт должны быть числами от 0');
            return;
          }
          Navigator.pop(context, values);
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}

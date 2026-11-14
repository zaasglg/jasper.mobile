import '../widgets/task_detail_style.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import '../../../../core/theme/task_label_color.dart';
import '../widgets/task_comment_attachment.dart';
import '../widgets/task_relationships.dart';
import '../widgets/task_dates_sheet.dart';
import '../widgets/task_resource_pairs.dart';
import '../widgets/task_location_section.dart';
import '../widgets/task_rich_description.dart';
import '../../data/models/task_location_model.dart';
import '../../domain/utils/task_column_label.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../storage/data/storage_models.dart';
import '../../../storage/data/storage_collector.dart';
import '../widgets/task_files_section.dart';
import '../../data/services/task_file_picker.dart';
import '../widgets/task_extras_sheet.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../widgets/task_details_skeleton.dart';
import '../../../../core/utils/html_text.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_detail_model.dart';
import '../../domain/utils/my_tasks_utils.dart';
import '../../domain/repositories/task_details_repository.dart';
import '../cubit/task_details_cubit.dart';
import '../cubit/task_details_state.dart';
import '../widgets/task_assignees_editor.dart';
import '../widgets/task_timing_panel.dart';
import '../widgets/task_checklists_editor.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({super.key, required this.taskId, this.task});

  final String taskId;
  final ProjectTaskModel? task;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _showHistory = false;
  bool _filesGrid = false;
  bool _pickingFiles = false;
  bool _addingChecklist = false;
  bool _pickingCommentFiles = false;
  final List<TaskFileModel> _commentFiles = [];

  Future<void> _previewFile(TaskFileModel file) async {
    final task = context.read<TaskDetailsCubit>().state.task;
    if (task == null) return;
    final workspaceId = sl.isRegistered<WorkspaceSelectionStorage>()
        ? await sl<WorkspaceSelectionStorage>().read()
        : null;
    if (!mounted) return;
    await context.push(
      '/storage-file',
      extra: (
        StorageScope(
          source: StorageSource.project,
          id: task.projectId,
          workspaceId: workspaceId ?? '',
          title: task.title,
        ),
        StorageItem(
          id: file.id,
          name: file.name,
          kind: StorageCollector.classify(file.name, file.type),
          date: file.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          dataUrl: file.dataUrl,
          mimeType: file.type,
          sizeLabel: StorageCollector.formatSize(file.size),
          taskId: task.id,
        ),
      ),
    );
  }

  Future<void> _pickCommentFiles() async {
    final cubit = context.read<TaskDetailsCubit>();
    if (_pickingCommentFiles || cubit.state.isSaving) return;
    setState(() => _pickingCommentFiles = true);
    try {
      final files = await TaskFilePicker.pick(
        author: cubit.state.currentUser?.name,
        authorId: cubit.state.currentUser?.id,
      );
      if (!mounted) return;
      if (_commentFiles.length + files.length > 10) {
        throw const TaskDetailsException(
          'К комментарию можно приложить до 10 файлов.',
        );
      }
      setState(() => _commentFiles.addAll(files));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TaskDetailsException
                  ? e.message
                  : 'Не удалось добавить файлы.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingCommentFiles = false);
    }
  }

  Future<void> _pickFiles() async {
    final cubit = context.read<TaskDetailsCubit>();
    if (_pickingFiles || cubit.state.isSaving) return;
    setState(() => _pickingFiles = true);
    try {
      final files = await TaskFilePicker.pick(
        author: cubit.state.currentUser?.name,
        authorId: cubit.state.currentUser?.id,
      );
      if (!mounted || cubit.isClosed || files.isEmpty) return;
      final saved = await cubit.addFiles(files);
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файлы загружены')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TaskDetailsException
                  ? error.message
                  : 'Не удалось прочитать выбранные файлы. Повторите попытку.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailsCubit, TaskDetailsState>(
      listenWhen: (previous, current) =>
          previous.actionRevision != current.actionRevision,
      listener: (context, state) {
        final message = state.actionErrorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        final task = state.task ?? widget.task;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: DashboardAppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: AppBar(
                primary: false,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                titleSpacing: 0,
                title: Text(
                  task?.displayId.trim().isNotEmpty == true
                      ? task!.displayId
                      : 'Задача',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: <Widget>[
                  AppActionMenuButton<TaskExtraTab>(
                    enabled:
                        task != null &&
                        !state.isSaving &&
                        state.status == TaskDetailsStatus.success,
                    title: 'Действия задачи',
                    tooltip: 'Действия задачи',
                    groups: const [
                      [
                        AppMenuAction(
                          value: TaskExtraTab.labels,
                          label: 'Метки и личные метки',
                          icon: LucideIcons.tag,
                        ),
                        AppMenuAction(
                          value: TaskExtraTab.epics,
                          label: 'Эпики',
                          icon: LucideIcons.layers3,
                        ),
                        AppMenuAction(
                          value: TaskExtraTab.resources,
                          label: 'Ресурсы',
                          icon: LucideIcons.chartNoAxesCombined,
                        ),
                        AppMenuAction(
                          value: TaskExtraTab.files,
                          label: 'Файлы',
                          icon: LucideIcons.paperclip,
                        ),
                      ],
                    ],
                    onSelected: (tab) => showTaskExtras(context, tab),
                  ),

                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: context.read<TaskDetailsCubit>().refresh,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: AppIconSizes.standard,
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: _body(context, state, task),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    TaskDetailsState state,
    ProjectTaskModel? task,
  ) {
    if (state.status == TaskDetailsStatus.initial ||
        state.status == TaskDetailsStatus.loading) {
      return const TaskDetailsSkeleton();
    }
    if (task == null) {
      return _DetailsError(
        message: state.errorMessage ?? 'Задача не найдена.',
        onRetry: () => context.read<TaskDetailsCubit>().load(widget.taskId),
      );
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator.adaptive(
          onRefresh: context.read<TaskDetailsCubit>().refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              if (state.status == TaskDetailsStatus.failure)
                _InlineError(message: state.errorMessage ?? 'Ошибка загрузки'),
              _TaskHeader(
                task: task,
                isSaving: state.isSaving,
                labels: state.visibleLabels,
                columnName: taskColumnLabel(
                  task.status,
                  columns: state.columns,
                ),
                onToggleCompleted: context
                    .read<TaskDetailsCubit>()
                    .toggleCompleted,
              ),
              const SizedBox(height: 20),
              _Description(
                value: state.detail.description,
                onTap: () => _editDescription(state.detail.description),
              ),
              const SizedBox(height: 14),
              _MetadataStrip(
                task: task,
                detail: state.detail,
                onDeadlineTap: () => _selectDeadline(task.end),
                onTimingTap: state.isSaving
                    ? null
                    : () => _editTiming(
                        state.detail.estimateMinutes ??
                            (task.estimate * 60).round(),
                      ),
                onAssigneesTap: state.isSaving
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => TaskAssigneesEditor(
                          cubit: context.read<TaskDetailsCubit>(),
                        ),
                      ),
              ),
              TaskLocationSection(
                location: TaskLocationModel.parse(state.detail.raw['location']),
                cubit: context.read<TaskDetailsCubit>(),
                enabled: !state.isSaving,
              ),
              const SizedBox(height: 12),
              TaskRelationships(
                task: task,
                cubit: context.read<TaskDetailsCubit>(),
                enabled: !state.isSaving,
              ),
              const SizedBox(height: 18),
              _ExpandableSection(
                icon: LucideIcons.chartNoAxesCombined,
                title: 'Ресурс',
                count: (state.resources.length / 2).ceil(),
                onAdd: state.isSaving
                    ? null
                    : () =>
                          context.read<TaskDetailsCubit>().createResourcePair(),
                initiallyExpanded: state.resources.isNotEmpty,
                child: TaskResourcePairs(resources: state.resources),
              ),
              _ExpandableSection(
                icon: LucideIcons.listChecks,
                title: 'Чек-листы',
                count: state.detail.checklistTotal,
                progress: state.detail.checklistProgress,
                initiallyExpanded: state.detail.checklists.isNotEmpty,
                onAdd: state.isSaving
                    ? null
                    : () => setState(() => _addingChecklist = true),
                child: TaskChecklistsEditor(
                  checklists: state.detail.checklists,
                  enabled: !state.isSaving,
                  showCreation: _addingChecklist,
                  onCloseCreation: () =>
                      setState(() => _addingChecklist = false),
                ),
              ),
              _ExpandableSection(
                icon: LucideIcons.messageSquare,
                title: 'Обсуждение',
                count: state.detail.comments.length,
                initiallyExpanded: state.detail.comments.isNotEmpty,
                child: _Discussion(
                  currentUserId: state.currentUser?.id,
                  comments: state.detail.comments,
                  controller: _commentController,
                  isSending: state.isSaving || _pickingCommentFiles,
                  onSend: _sendComment,
                  draftFiles: _commentFiles,
                  onAttach: _pickCommentFiles,
                  onRemove: (file) =>
                      setState(() => _commentFiles.remove(file)),
                  onOpenFile: _previewFile,
                ),
              ),
              const SizedBox(height: 10),
              _DetailTabs(
                historySelected: _showHistory,
                filesGrid: _filesGrid,
                onViewChanged: (value) => setState(() => _filesGrid = value),
                fileCount: state.detail.files.length,
                historyCount: state.history.length,
                onChanged: (value) => setState(() => _showHistory = value),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showHistory
                    ? _History(
                        key: const ValueKey<String>('history'),
                        entries: state.history,
                      )
                    : TaskFilesSection(
                        key: const ValueKey<String>('files'),
                        files: state.detail.files,
                        grid: _filesGrid,
                        uploading: _pickingFiles || state.isSaving,
                        onAdd: _pickFiles,
                        onOpen: _previewFile,
                      ),
              ),
            ],
          ),
        ),
        if (state.isSaving)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _editDescription(String value) async {
    final cubit = context.read<TaskDetailsCubit>();
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskRichDescriptionEditor(
        initial: value,
        onSave: (html) async =>
            html == value || await cubit.updateDescription(html),
      ),
    );
  }

  Future<void> _selectDeadline(DateTime? current) => _selectDates();

  Future<void> _selectDates({bool selectStart = false}) {
    final cubit = context.read<TaskDetailsCubit>();
    return showTaskDatesSheet(
      context,
      start: cubit.state.task?.start,
      end: cubit.state.task?.end,
      selectStart: selectStart,
      onSave: cubit.updateDates,
    );
  }

  Future<void> _editTiming(int currentMinutes) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TimingEditor(minutes: currentMinutes),
    );
    if (result != null && mounted) {
      await context.read<TaskDetailsCubit>().updateEstimate(result);
    }
  }

  Future<void> _sendComment() async {
    final value = _commentController.text.trim();
    if (value.isEmpty && _commentFiles.isEmpty) return;
    final cubit = context.read<TaskDetailsCubit>();
    final success = await cubit.addComment(
      value,
      files: List.of(_commentFiles),
    );
    if (mounted && success) {
      _commentController.clear();
      setState(() => _commentFiles.clear());
    }
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.task,
    required this.labels,
    required this.columnName,
    required this.onToggleCompleted,
    required this.isSaving,
  });

  final ProjectTaskModel task;
  final List<TaskLabelModel> labels;
  final String columnName;
  final VoidCallback onToggleCompleted;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            _SoftChip(icon: LucideIcons.columns3, label: columnName),
            for (final epic in task.epicNames)
              _SoftChip(icon: LucideIcons.layers3, label: epic),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            InkWell(
              key: const Key('task-complete-toggle'),
              onTap: isSaving ? null : onToggleCompleted,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: task.isDone
                          ? AppColors.accent
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: task.isDone
                          ? null
                          : Border.all(
                              color: colors.outlineVariant,
                              width: 1.5,
                            ),
                    ),
                    child: task.isDone
                        ? const Icon(
                            LucideIcons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _TaskTitleEditor(
                title: task.title,
                disabled: isSaving,
                onSave: context.read<TaskDetailsCubit>().updateTitle,
              ),
            ),
          ],
        ),
        if (task.epics.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.smMd),
          Text('Эпики', style: AppTypography.caption(context)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final epic in task.epics)
                _LabelChip(
                  label: TaskLabelModel(
                    id: epic.id,
                    text: epic.name,
                    color: epic.color,
                  ),
                ),
            ],
          ),
        ],
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: labels
                .map((label) => _LabelChip(label: label))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayText = htmlToPlainText(value);
    final isEmpty = displayText.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              LucideIcons.alignLeft,
              size: AppIconSizes.standard,
              color: AppColors.ink,
            ),
            const SizedBox(width: 9),
            Text('Описание', style: TaskDetailStyle.heading(context)),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: TaskDetailStyle.field(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: isEmpty
                        ? const Text(
                            'Добавить описание…',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          )
                        : TaskRichDescriptionView(value: value, maxLines: 6),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.pencil,
                    size: AppIconSizes.standard,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({
    required this.task,
    required this.detail,
    required this.onDeadlineTap,
    required this.onAssigneesTap,
    required this.onTimingTap,
  });

  final ProjectTaskModel task;
  final TaskDetailModel detail;
  final VoidCallback onDeadlineTap;
  final VoidCallback? onAssigneesTap;
  final VoidCallback? onTimingTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.smMd) / 2;
        return Wrap(
          spacing: AppSpacing.smMd,
          runSpacing: AppSpacing.smMd,
          children: <Widget>[
            _MetadataCard(
              width: itemWidth,
              label: 'Исполнители',
              icon: LucideIcons.users,
              onTap: onAssigneesTap,
              child: task.assignees.isEmpty
                  ? const Text('Не назначены')
                  : _Assignees(assignees: task.assignees),
            ),
            _MetadataCard(
              width: itemWidth,
              label: 'Срок',
              icon: LucideIcons.calendarClock,
              onTap: onDeadlineTap,
              child: Text(
                task.end == null
                    ? 'Без срока'
                    : formatRussianTaskDate(task.end!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isTaskOverdue(task, DateTime.now())
                      ? AppColors.error
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: TaskTimingPanel(
                cubit: context.read<TaskDetailsCubit>(),
                onEdit: onTimingTap ?? () {},
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.child,
    this.onTap,
  });

  final double width;
  final String label;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height:
          TaskDetailStyle.metadataMinHeight *
          MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
      child: Material(
        color: TaskDetailStyle.field(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: AppIconSizes.standard,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaskDetailStyle.label(context),
                      ),
                    ),
                    if (onTap != null) ...<Widget>[
                      const Spacer(),
                      const Icon(
                        LucideIcons.pencil,
                        size: AppIconSizes.standard,
                        color: AppColors.muted,
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                DefaultTextStyle(
                  style: AppTypography.body(context)!.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.child,
    this.progress,
    this.onAdd,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final int count;
  final double? progress;
  final VoidCallback? onAdd;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  Widget _progressBar() => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: widget.progress!.clamp(0, 1),
      minHeight: 3,
      backgroundColor: AppColors.skeletonTrack,
      color: AppColors.accent,
    ),
  );

  Widget _percentage() => Text(
    '${(widget.progress! * 100).round()}%',
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.muted,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final inlineProgress =
                widget.progress != null &&
                constraints.maxWidth >= 340 &&
                MediaQuery.textScalerOf(context).scale(13) <= 16;
            return Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                key: ValueKey('task-section-${widget.title}'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            Icon(
                              _expanded
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronRight,
                              key: ValueKey(
                                'section-disclosure-${widget.title}',
                              ),
                              size: AppIconSizes.standard,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              widget.icon,
                              key: ValueKey('section-icon-${widget.title}'),
                              size: AppIconSizes.standard,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.title,
                                      style: TaskDetailStyle.heading(context),
                                    ),
                                  ),
                                  if (widget.count > 0 ||
                                      widget.title == 'РЕСУРС') ...[
                                    const SizedBox(width: 6),
                                    _CountBadge(count: widget.count),
                                  ],
                                ],
                              ),
                            ),
                            if (inlineProgress) ...[
                              const SizedBox(width: 8),
                              _percentage(),
                              const SizedBox(width: 8),
                              SizedBox(width: 64, child: _progressBar()),
                            ],
                            if (widget.onAdd != null ||
                                widget.progress != null ||
                                widget.title == 'РЕСУРС') ...[
                              const SizedBox(width: 4),
                              IconButton(
                                key: ValueKey(
                                  'task-section-add-${widget.title}',
                                ),
                                tooltip: widget.title == 'РЕСУРС'
                                    ? 'Добавить ресурс'
                                    : 'Добавить чек-лист',
                                onPressed: widget.onAdd == null
                                    ? null
                                    : () {
                                        setState(() => _expanded = true);
                                        widget.onAdd!();
                                      },
                                icon: const Icon(
                                  LucideIcons.plus,
                                  size: AppIconSizes.standard,
                                ),
                                color: AppColors.accent,
                                constraints: const BoxConstraints.tightFor(
                                  width: 48,
                                  height: 48,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.progress != null && !inlineProgress)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 0, 44, 6),
                          child: Row(
                            children: [
                              _percentage(),
                              const SizedBox(width: 10),
                              Expanded(child: _progressBar()),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 150),
          sizeCurve: Curves.easeOutCubic,
        ),
        Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.38),
        ),
      ],
    );
  }
}

class _Discussion extends StatelessWidget {
  const _Discussion({
    required this.comments,
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.currentUserId,
    required this.draftFiles,
    required this.onAttach,
    required this.onRemove,
    required this.onOpenFile,
  });
  final List<TaskFileModel> draftFiles;
  final VoidCallback onAttach;
  final ValueChanged<TaskFileModel> onRemove, onOpenFile;

  final List<TaskCommentModel> comments;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _EmptyText('Комментариев пока нет.'),
          )
        else
          for (final comment in comments)
            _CommentBubble(
              comment: comment,
              onOpenFile: onOpenFile,
              isMine:
                  currentUserId != null &&
                  currentUserId!.isNotEmpty &&
                  comment.authorId == currentUserId,
            ),
        if (draftFiles.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final file in draftFiles)
                InputChip(
                  label: Text(file.name, overflow: TextOverflow.ellipsis),
                  onPressed: () => onOpenFile(file),
                  onDeleted: isSending ? null : () => onRemove(file),
                ),
            ],
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              IconButton(
                key: const Key('discussion_attach'),
                constraints: const BoxConstraints.tightFor(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                ),
                tooltip: 'Прикрепить файлы к комментарию',
                onPressed: isSending ? null : onAttach,
                icon: const Icon(
                  LucideIcons.paperclip,
                  size: AppIconSizes.standard,
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('discussion_input'),
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTypography.body(context),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Написать комментарий…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.smMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filled(
                key: const Key('discussion_send'),
                constraints: const BoxConstraints.tightFor(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                ),
                tooltip: 'Отправить',
                onPressed: isSending ? null : onSend,
                icon: const Icon(
                  LucideIcons.send,
                  size: AppIconSizes.standard,
                  color: AppColors.onAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isMine,
    required this.onOpenFile,
  });
  final ValueChanged<TaskFileModel> onOpenFile;

  final TaskCommentModel comment;
  final bool isMine;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LayoutBuilder(
      builder: (context, constraints) => Align(
        key: ValueKey('comment-alignment-${comment.id}'),
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.88),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                UserAvatar(
                  size: 30,
                  userId: comment.authorId,
                  name: comment.author,
                  avatarUrl:
                      (comment.raw['authorAvatarUrl'] ??
                              comment.raw['avatarUrl'])
                          as String?,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFFEDE9FC)
                        : const Color(0xFFF3F3F2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMine ? 14 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 14),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMine ? 'Вы' : comment.author,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (htmlToPlainText(comment.text).trim().isNotEmpty)
                        Text(
                          htmlToPlainText(comment.text),
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      for (final file in comment.files)
                        TaskCommentAttachment(
                          file: file,
                          onOpen: () => onOpenFile(file),
                        ),
                      if (_commentTime(comment.time).isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _commentTime(comment.time),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.historySelected,
    required this.filesGrid,
    required this.onViewChanged,
    required this.fileCount,
    required this.historyCount,
    required this.onChanged,
  });

  final bool historySelected;
  final bool filesGrid;
  final ValueChanged<bool> onViewChanged;
  final int fileCount;
  final int historyCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TabButton(
                    selected: !historySelected,
                    icon: LucideIcons.paperclip,
                    label: 'Файлы',
                    count: fileCount,
                    onTap: () => onChanged(false),
                  ),
                  const SizedBox(width: 6),
                  _TabButton(
                    selected: historySelected,
                    icon: LucideIcons.history,
                    label: 'История',
                    count: historyCount,
                    onTap: () => onChanged(true),
                  ),
                ],
              ),
            ),
          ),
          if (!historySelected) ...[
            const SizedBox(width: 8),
            TaskFilesViewToggle(grid: filesGrid, onChanged: onViewChanged),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: AppIconSizes.standard,
              color: selected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
            ),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({super.key, required this.entries});

  final List<TaskHistoryEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _EmptyText('Нет записей истории.');
    return Column(
      children: entries
          .map((entry) => _HistoryRow(entry: entry))
          .toList(growable: false),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final TaskHistoryEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.zap,
              size: AppIconSizes.standard,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${entry.actorName ?? 'Пользователь'} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: _historyLabel(entry)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dateTime(entry.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.085),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppIconSizes.standard, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final TaskLabelModel label;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Assignees extends StatelessWidget {
  const _Assignees({required this.assignees});

  final List<TaskAssigneeModel> assignees;

  @override
  Widget build(BuildContext context) {
    final visible = assignees.take(3).toList(growable: false);
    return Tooltip(
      message: assignees
          .map((user) => user.name.isEmpty ? 'Исполнитель' : user.name)
          .join('\n'),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28 + (visible.length - 1) * 18,
            height: 28,
            child: Stack(
              children: <Widget>[
                for (var index = 0; index < visible.length; index++)
                  Positioned(
                    left: index * 18,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF5F5F4),
                      ),
                      child: UserAvatar(
                        size: 24,
                        userId: visible[index].userId,
                        name: visible[index].name,
                        avatarUrl: visible[index].avatarUrl,
                        backgroundColor: AppColors.accent.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (assignees.length == 1) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                assignees.first.name.trim().isEmpty
                    ? 'Исполнитель'
                    : assignees.first.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _TimingEditor extends StatefulWidget {
  const _TimingEditor({required this.minutes});
  final int minutes;
  @override
  State<_TimingEditor> createState() => _TimingEditorState();
}

class _TimingEditorState extends State<_TimingEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  @override
  void initState() {
    super.initState();
    _hours = TextEditingController(text: '${widget.minutes ~/ 60}');
    _minutes = TextEditingController(text: '${widget.minutes % 60}');
  }

  @override
  void dispose() {
    _minutes.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        int.parse(_hours.text.trim()) * 60 + int.parse(_minutes.text.trim()),
      );
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
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Тайминг задачи',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E4E2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('task-timing-hours'),
                      controller: _hours,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration('ч'),
                      validator: _validateDuration,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      key: const Key('task-timing-minutes'),
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: _fieldDecoration('мин'),
                      validator: _validateDuration,
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Убрать тайминг'),
            ),
          ],
        ),
      ),
    ),
  );

  String? _validateDuration(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 0 ? 'Введите целое число от 0' : null;
  }

  InputDecoration _fieldDecoration(String unit) => InputDecoration(
    hintText: '0',
    suffixText: unit,
    filled: true,
    fillColor: const Color(0xFFF5F5F4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent),
    ),
  );
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              LucideIcons.circleAlert,
              color: AppColors.muted,
              size: AppIconSizes.standard,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

String _historyLabel(TaskHistoryEntryModel entry) {
  final change = entry.fromValue != null || entry.toValue != null
      ? ' (${entry.fromValue ?? '—'} → ${entry.toValue ?? '—'})'
      : '';
  return switch (entry.type) {
    'title_changed' => 'изменил(а) название$change',
    'priority_changed' => 'изменил(а) приоритет$change',
    'date_changed' => 'изменил(а) срок',
    'task_completed' => 'завершил(а) задачу',
    'task_reopened' => 'вернул(а) задачу в работу',
    'progress_changed' => 'изменил(а) прогресс$change',
    'description_changed' => 'изменил(а) описание',
    'label_added' => 'добавил(а) метку ${entry.subjectName ?? ''}',
    'label_removed' => 'удалил(а) метку ${entry.subjectName ?? ''}',
    'assignee_added' => 'добавил(а) исполнителя ${entry.subjectName ?? ''}',
    'assignee_removed' => 'удалил(а) исполнителя ${entry.subjectName ?? ''}',
    'epic_added' => 'добавил(а) эпик ${entry.subjectName ?? ''}',
    'epic_removed' => 'удалил(а) эпик ${entry.subjectName ?? ''}',
    'task_created' => 'создал(а) задачу',
    _ => 'обновил(а) задачу',
  };
}

String _commentTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : _dateTime(parsed);
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return '${formatRussianTaskDate(local)}, $hours:$minutes';
}

Color _parseColor(String value) => taskLabelColor(value);

class _TaskTitleEditor extends StatefulWidget {
  const _TaskTitleEditor({
    required this.title,
    required this.disabled,
    required this.onSave,
  });
  final String title;
  final bool disabled;
  final Future<bool> Function(String) onSave;

  @override
  State<_TaskTitleEditor> createState() => _TaskTitleEditorState();
}

class _TaskTitleEditorState extends State<_TaskTitleEditor> {
  final _controller = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || widget.disabled) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Введите название задачи');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.onSave(title);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) {
        _editing = false;
        FocusScope.of(context).unfocus();
      } else {
        _error = 'Не удалось сохранить. Попробуйте ещё раз.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.pageTitle(
      context,
    )?.copyWith(height: 1.3, color: Theme.of(context).colorScheme.onSurface);
    if (!_editing) {
      return InkWell(
        key: const Key('task-title-edit'),
        borderRadius: BorderRadius.circular(8),
        onTap: widget.disabled
            ? null
            : () => setState(() {
                _controller.text = widget.title;
                _controller.selection = TextSelection.collapsed(
                  offset: _controller.text.length,
                );
                _error = null;
                _editing = true;
              }),
        child: Text(
          widget.title.trim().isEmpty ? 'Без названия' : widget.title,
          style: style,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('task-title-field'),
          controller: _controller,
          autofocus: true,
          enabled: !_saving && !widget.disabled,
          style: style,
          minLines: 1,
          maxLines: null,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.error),
            ),
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                key: const Key('task-title-save'),
                tooltip: 'Сохранить',
                onPressed: widget.disabled ? null : _save,
                icon: const Icon(
                  LucideIcons.check,
                  size: AppIconSizes.standard,
                  color: AppColors.accent,
                ),
              ),
            IconButton(
              key: const Key('task-title-cancel'),
              tooltip: 'Отмена',
              onPressed: _saving || widget.disabled
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _editing = false;
                        _error = null;
                      });
                    },
              icon: const Icon(
                LucideIcons.x,
                size: AppIconSizes.standard,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

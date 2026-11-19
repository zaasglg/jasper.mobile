import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../../workspaces/data/models/workspace_model.dart';
import '../../domain/entities/task_move_target.dart';
import '../../domain/repositories/kanban_repository.dart';
import '../../domain/repositories/task_move_repository.dart';
import '../cubit/kanban_state.dart';

enum _LoadStage { catalog, projects, columns }

class TaskMoveSheet extends StatefulWidget {
  const TaskMoveSheet({
    super.key,
    required this.project,
    required this.task,
    required this.state,
    required this.onMove,
    this.repository,
  });
  final ProjectModel project;
  final ProjectTaskModel task;
  final KanbanState state;
  final TaskMoveRepository? repository;
  final Future<bool> Function(TaskMoveTarget target) onMove;
  @override
  State<TaskMoveSheet> createState() => _TaskMoveSheetState();
}

class _TaskMoveSheetState extends State<TaskMoveSheet> {
  late String _workspaceId = widget.project.workspaceId;
  late String? _projectId = widget.project.id;
  late String? _status = widget.task.status;
  late List<WorkspaceModel> _workspaces = [
    WorkspaceModel(id: _workspaceId, name: 'Текущее пространство'),
  ];
  late List<ProjectModel> _projects = [widget.project];
  List<KanbanColumnModel> _remoteColumns = [];
  bool _loadingCatalog = false,
      _loadingProjects = false,
      _loadingColumns = false,
      _saving = false;
  int _position = 0;
  bool _append = true;
  String? _loadError, _moveError;
  _LoadStage _failedStage = _LoadStage.catalog;
  CancelToken? _catalogToken, _projectsToken, _columnsToken;
  bool get _local => _projectId == widget.project.id;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _loadCatalog();
  }

  @override
  void dispose() {
    _catalogToken?.cancel();
    _projectsToken?.cancel();
    _columnsToken?.cancel();
    super.dispose();
  }

  String _message(Object error) => error is KanbanException
      ? error.message
      : 'Не удалось загрузить места назначения. Повторите попытку.';

  Future<void> _loadCatalog() async {
    _catalogToken?.cancel();
    final token = _catalogToken = CancelToken();
    setState(() {
      _loadingCatalog = true;
      _loadError = null;
    });
    try {
      final items = await widget.repository!.workspaces(cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _workspaces = items;
        if (!_workspaces.any((item) => item.id == _workspaceId)) {
          _workspaces = [
            WorkspaceModel(id: _workspaceId, name: 'Текущее пространство'),
            ...items,
          ];
        }
      });
      await _loadProjects();
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _loadError = _message(error);
          _failedStage = _LoadStage.catalog;
        });
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _loadingCatalog = false);
      }
    }
  }

  Future<void> _loadProjects() async {
    _projectsToken?.cancel();
    final token = _projectsToken = CancelToken();
    final workspace = _workspaceId;
    setState(() {
      _loadingProjects = true;
      _loadError = null;
    });
    try {
      final items = await widget.repository!.projects(
        workspace,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled || workspace != _workspaceId) return;
      setState(() {
        _projects = items;
        if (workspace == widget.project.workspaceId &&
            !_projects.any((item) => item.id == widget.project.id)) {
          _projects = [widget.project, ...items];
        }
      });
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _loadError = _message(error);
          _failedStage = _LoadStage.projects;
        });
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _loadingProjects = false);
      }
    }
  }

  void _selectWorkspace(String workspace) {
    if (workspace == _workspaceId) return;
    _projectsToken?.cancel();
    _columnsToken?.cancel();
    setState(() {
      _workspaceId = workspace;
      _projectId = null;
      _status = null;
      _projects = [];
      _remoteColumns = [];
      _loadingColumns = false;
      _moveError = null;
    });
    _loadProjects();
  }

  void _selectProject(String project) {
    if (project == _projectId) return;
    _columnsToken?.cancel();
    setState(() {
      _projectId = project;
      _status = null;
      _position = 0;
      _append = true;
      _remoteColumns = [];
      _loadError = null;
      _moveError = null;
      _loadingColumns = false;
    });
    if (_local) {
      setState(
        () => _status = widget.state.columns
            .where((column) => !column.archived)
            .firstOrNull
            ?.statusMap,
      );
    } else {
      _loadColumns();
    }
  }

  Future<void> _loadColumns() async {
    _columnsToken?.cancel();
    final token = _columnsToken = CancelToken();
    final project = _projectId!;
    final workspace = _workspaceId;
    setState(() {
      _loadingColumns = true;
      _loadError = null;
    });
    try {
      final items = await widget.repository!.columns(
        workspace,
        project,
        cancelToken: token,
      );
      if (!mounted ||
          token.isCancelled ||
          project != _projectId ||
          workspace != _workspaceId) {
        return;
      }
      setState(() {
        _remoteColumns = items;
        _status = items.firstOrNull?.statusMap;
      });
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _loadError = _message(error);
          _failedStage = _LoadStage.columns;
        });
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _loadingColumns = false);
      }
    }
  }

  Future<void> _retry() => switch (_failedStage) {
    _LoadStage.catalog => _loadCatalog(),
    _LoadStage.projects => _loadProjects(),
    _LoadStage.columns => _loadColumns(),
  };

  Future<void> _confirm(KanbanColumnModel column) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _moveError = null;
    });
    try {
      final success = await widget.onMove(
        TaskMoveTarget(
          workspaceId: _workspaceId,
          projectId: _projectId!,
          status: column.statusMap,
          position: _local || !_append ? _position : null,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(
          () => _moveError =
              widget.state.actionErrorMessage ??
              'Не удалось переместить задачу. Попробуйте ещё раз.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _moveError = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = widget.state.tasks
        .where((task) => task.id == widget.task.id && !task.archived)
        .firstOrNull;
    final available =
        widget.state.projectId == widget.project.id && currentTask != null;
    final columns = (_local ? widget.state.columns : _remoteColumns)
        .where((column) => !column.archived)
        .toList();
    final column = columns
        .where(
          (column) => column.statusMap.toUpperCase() == _status?.toUpperCase(),
        )
        .firstOrNull;
    final count = column == null
        ? 0
        : widget.state.tasks
              .where(
                (task) =>
                    task.id != widget.task.id &&
                    task.status.toUpperCase() == column.statusMap.toUpperCase(),
              )
              .length;
    _position = _position.clamp(0, count);
    final canMove =
        available &&
        column != null &&
        !_saving &&
        !_loadingColumns &&
        !widget.state.movingTaskIds.contains(widget.task.id);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.arrowRightLeft,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Переместить задачу',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormField(
                        key: const Key('move-workspace-field'),
                        label: 'Рабочее пространство',
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('move-workspace-$_workspaceId'),
                          initialValue: _workspaceId,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          items: [
                            for (final item in _workspaces)
                              DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _saving || widget.repository == null
                              ? null
                              : (value) {
                                  if (value != null) _selectWorkspace(value);
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        key: const Key('move-project-field'),
                        label: 'Проект',
                        child: DropdownButtonFormField<String>(
                          key: ValueKey((
                            'move-project',
                            _workspaceId,
                            _projectId,
                            Object.hashAll(_projects),
                          )),
                          initialValue: _projectId,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          hint: Text(
                            _loadingProjects
                                ? 'Загрузка проектов…'
                                : 'Выберите проект',
                          ),
                          items: [
                            for (final item in _projects)
                              DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged:
                              _saving ||
                                  _loadingProjects ||
                                  widget.repository == null
                              ? null
                              : (value) {
                                  if (value != null) _selectProject(value);
                                },
                        ),
                      ),
                      if (_loadingCatalog ||
                          _loadingProjects ||
                          _loadingColumns)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_loadError != null) _error(_loadError!, retry: true),
                      if (!_loadingProjects &&
                          _projects.isEmpty &&
                          _loadError == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'В этом пространстве нет доступных проектов.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'В какую колонку?',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_projectId == null)
                        const Text(
                          'Сначала выберите проект.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      if (_projectId != null &&
                          !_loadingColumns &&
                          columns.isEmpty &&
                          _loadError == null)
                        const Text(
                          'В проекте нет доступных колонок.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      for (final item in columns)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: item == column
                                ? AppColors.accent.withValues(alpha: .06)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: item == column
                                    ? AppColors.accent.withValues(alpha: .4)
                                    : AppColors.border,
                              ),
                            ),
                            child: ListTile(
                              key: ValueKey('move-to-${item.id}'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              leading: Icon(
                                LucideIcons.columns3,
                                color: item == column
                                    ? AppColors.accent
                                    : AppColors.muted,
                                size: 20,
                              ),
                              title: Text(
                                item.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle:
                                  _local &&
                                      item.statusMap.toUpperCase() ==
                                          currentTask?.status.toUpperCase()
                                  ? const Text('Текущая колонка')
                                  : null,
                              trailing: Icon(
                                item == column
                                    ? LucideIcons.circleCheck
                                    : LucideIcons.circle,
                                size: 20,
                                color: item == column
                                    ? AppColors.accent
                                    : AppColors.muted,
                              ),
                              onTap: _saving
                                  ? null
                                  : () => setState(() {
                                      _status = item.statusMap;
                                      _position = 0;
                                      _moveError = null;
                                    }),
                            ),
                          ),
                        ),
                      if (column != null) ...[
                        const SizedBox(height: 6),
                        AppFormField(
                          label: 'Позиция',
                          child: _local
                              ? DropdownButtonFormField<int>(
                                  key: ValueKey((_status, count, _position)),
                                  initialValue: _position,
                                  isExpanded: true,
                                  items: [
                                    for (var index = 0; index <= count; index++)
                                      DropdownMenuItem(
                                        value: index,
                                        child: Text('${index + 1}'),
                                      ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(
                                          () => _position = value ?? 0,
                                        ),
                                )
                              : DropdownButtonFormField<bool>(
                                  key: ValueKey(('move-position', _projectId)),
                                  initialValue: _append,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: true,
                                      child: Text('В конец колонки'),
                                    ),
                                    DropdownMenuItem(
                                      value: false,
                                      child: Text('В начало колонки'),
                                    ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(() {
                                          _append = value ?? true;
                                          _position = 0;
                                        }),
                                ),
                        ),
                      ],
                      if (!_local && _projectId != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'При смене проекта связи с эпиками будут убраны. Исполнители без доступа к новому проекту будут сняты.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_moveError != null) _error(_moveError!),
                    FilledButton(
                      key: const Key('confirm-task-move'),
                      onPressed: canMove ? () => _confirm(column) : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              !available
                                  ? 'Задача больше недоступна'
                                  : column == null
                                  ? 'Выберите колонку'
                                  : 'Перенести в «${column.name}»',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(String text, {bool retry = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.error),
            ),
          ),
          if (retry)
            TextButton(
              onPressed: _saving ? null : _retry,
              child: const Text('Повторить'),
            ),
        ],
      ),
    ),
  );
}

import 'package:jospar/core/localization/app_translations.dart';
import '../../domain/entities/project_model.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../kanban/presentation/widgets/board_style.dart';
import '../../../storage/domain/entities/storage_scope.dart';
import '../../../storage/domain/entities/storage_enums.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../kanban/presentation/widgets/kanban_board.dart';
import '../../../kanban/presentation/cubit/kanban_cubit.dart';
import '../../../kanban/presentation/cubit/kanban_state.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    required this.projectId,
    this.initialProject,
    super.key,
  });

  final String projectId;
  final ProjectModel? initialProject;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _boardKey = GlobalKey<KanbanBoardState>();

  Future<void> _showProjectActions(ProjectModel project) async {
    final action = await showAppActionMenu<String>(
      context,
      title: project.name,
      groups: [
        [
          const AppMenuAction(
            value: 'epics',
            label: 'Эпики',
            icon: LucideIcons.layers,
          ),
          const AppMenuAction(
            value: 'view',
            label: 'Вид карточек',
            icon: LucideIcons.panelsTopLeft,
          ),
        ],
        [
          const AppMenuAction(
            value: 'members',
            label: 'Участники',
            icon: LucideIcons.users,
          ),
          const AppMenuAction(
            value: 'storage',
            label: 'Кладовка',
            icon: LucideIcons.archive,
          ),
          const AppMenuAction(
            value: 'settings',
            label: 'Настройки проекта',
            icon: LucideIcons.settings,
          ),
        ],
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'epics':
        context.push(
          '/projects/${project.id}/epics',
          extra: context.read<KanbanCubit>(),
        );
      case 'view':
        _boardKey.currentState?.showCardView();
      case 'members':
        context.push('/projects/${project.id}/participants');
      case 'storage':
        context.push(
          '/storage',
          extra: StorageScope(
            source: StorageSource.project,
            id: project.id,
            workspaceId: project.workspaceId,
            title: project.name,
          ),
        );
      case 'settings':
        final cubit = context.read<ProjectsCubit>();
        final result = await context.push<String>(
          '/manage/projects/${project.id}',
        );
        await cubit.loadForWorkspace(project.workspaceId, refresh: true);
        if (mounted && result == 'removed') context.go('/projects');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        final project =
            _findProject(state.projects, widget.projectId) ??
            widget.initialProject;
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          appBar: DashboardAppBar(
            compact: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: AppBar(
                primary: false,
                toolbarHeight: 48,
                centerTitle: false,
                titleTextStyle: AppTypography.title(
                  context,
                )?.copyWith(fontSize: BoardStyle.columnTitleSize),
                shape: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white,
                surfaceTintColor: Colors.transparent,
                leading: AppBackButton(onPressed: context.pop),
                actions: [
                  if (project != null) ...[
                    IconButton(
                      key: const Key('board-add-column'),
                      tooltip: tr(context, 'Добавить колонку'),
                      icon: const Icon(
                        LucideIcons.plus,
                        size: BoardStyle.iconSize,
                      ),
                      onPressed: () =>
                          _boardKey.currentState?.showCreateColumn(),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Действия проекта'),
                      icon: const Icon(
                        LucideIcons.ellipsis,
                        size: BoardStyle.iconSize,
                      ),
                      onPressed: () => _showProjectActions(project),
                    ),
                  ],
                ],
                title: project == null
                    ? Text(tr(context, 'Проект'))
                    : _ProjectSwitcher(
                        project: project,
                        projects: state.projects,
                      ),
              ),
            ),
          ),
          body: project == null
              ? const _ProjectNotFound()
              : SafeArea(
                  child: _ProjectDetails(project: project, boardKey: _boardKey),
                ),
        );
      },
    );
  }

  ProjectModel? _findProject(List<ProjectModel> projects, String id) {
    for (final project in projects) {
      if (project.id == id) return project;
      final child = _findProject(project.children, id);
      if (child != null) return child;
    }
    return null;
  }
}

class _ProjectDetails extends StatelessWidget {
  const _ProjectDetails({required this.project, required this.boardKey});

  final GlobalKey<KanbanBoardState> boardKey;

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KanbanCubit, KanbanState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => Stack(
        children: <Widget>[
          KanbanBoard(key: boardKey, project: project, showToolbar: false),
          if (state.status == KanbanStatus.loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                key: Key('project-board-loader'),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectSwitcher extends StatelessWidget {
  const _ProjectSwitcher({required this.project, required this.projects});

  final ProjectModel project;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return AppActionMenuButton<ProjectModel>(
      title: tr(context, 'Выбрать проект'),
      tooltip: tr(context, 'Выбрать проект'),
      onSelected: (selected) =>
          context.go('/projects/${selected.id}', extra: selected),
      groups: [
        [
          for (final item in projects)
            AppMenuAction(
              value: item,
              label: item.name,
              icon: LucideIcons.folder,
              selected: item.id == project.id,
            ),
        ],
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(LucideIcons.chevronDown, size: AppIconSizes.standard),
        ],
      ),
    );
  }
}

class _ProjectNotFound extends StatelessWidget {
  const _ProjectNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        tr(context, 'Проект не найден'),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../kanban/presentation/widgets/kanban_board.dart';
import '../../../kanban/presentation/cubit/kanban_cubit.dart';
import '../../../kanban/presentation/cubit/kanban_state.dart';
import '../../data/models/project_model.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';

class ProjectDetailsScreen extends StatelessWidget {
  const ProjectDetailsScreen({
    required this.projectId,
    this.initialProject,
    super.key,
  });

  final String projectId;
  final ProjectModel? initialProject;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        final project =
            _findProject(state.projects, projectId) ?? initialProject;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Назад',
              onPressed: context.pop,
              icon: const Icon(LucideIcons.arrowLeft),
            ),
            title: project == null
                ? const Text('Проект')
                : _ProjectSwitcher(project: project, projects: state.projects),
          ),
          body: project == null
              ? const _ProjectNotFound()
              : _ProjectDetails(project: project),
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
  const _ProjectDetails({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KanbanCubit, KanbanState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: KanbanBoard(project: project),
          ),
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
    return PopupMenuButton<ProjectModel>(
      tooltip: 'Выбрать проект',
      onSelected: (selected) =>
          context.go('/projects/${selected.id}', extra: selected),
      itemBuilder: (_) => <PopupMenuEntry<ProjectModel>>[
        for (final item in projects)
          PopupMenuItem<ProjectModel>(
            value: item,
            child: Row(
              children: <Widget>[
                if (item.id == project.id)
                  const Icon(LucideIcons.check, size: 16),
                if (item.id == project.id) const SizedBox(width: 8),
                Expanded(child: Text(item.name)),
              ],
            ),
          ),
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
          const Icon(LucideIcons.chevronDown, size: 16),
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
        'Проект не найден',
        style: GoogleFonts.manrope(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

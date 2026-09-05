import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shell/presentation/screens/main_shell.dart';
import '../../../workspaces/data/models/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../data/models/project_model.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';
import '../widgets/create_project_sheet.dart';

const _ink = Color(0xFF16181D);
const _secondary = Color(0xFF8A9099);
const _border = Color(0xFFE3E6EC);
const _surface = Color(0xFFF7F8FA);
const _accent = Color(0xFF5B5FEF);

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, workspaceState) {
        final workspace = workspaceState is WorkspaceLoaded
            ? workspaceState.selected
            : null;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Открыть меню',
              onPressed: MainShell.openDrawer,
              icon: const Icon(LucideIcons.menu, color: _ink),
            ),
            title: Text(
              'Проекты',
              style: GoogleFonts.manrope(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.35,
              ),
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filled(
                  key: const Key('create_project_button'),
                  tooltip: workspace == null
                      ? 'Выберите workspace'
                      : 'Создать проект',
                  onPressed: workspace == null
                      ? null
                      : () => showCreateProjectFlow(context),
                  style: IconButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _border,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.square(40),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 20),
                ),
              ),
            ],
          ),
          body: workspace == null
              ? _WorkspaceUnavailable(state: workspaceState)
              : _ProjectsBody(
                  workspace: workspace,
                  onCreate: () => showCreateProjectFlow(context),
                ),
        );
      },
    );
  }
}

class _ProjectsBody extends StatelessWidget {
  const _ProjectsBody({required this.workspace, required this.onCreate});

  final WorkspaceModel workspace;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        return Column(
          children: <Widget>[
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: _surface,
              child: Row(
                children: <Widget>[
                  const Icon(LucideIcons.folder, size: 14, color: _accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  Text(
                    _projectCount(state.projects.length),
                    style: GoogleFonts.manrope(fontSize: 12, color: _secondary),
                  ),
                ],
              ),
            ),
            Expanded(child: _content(context, state)),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, ProjectsState state) {
    if (state.isLoading && state.projects.isEmpty) {
      return const _ProjectsLoading();
    }
    if (state.errorMessage != null && state.projects.isEmpty) {
      return _ProjectsError(
        message: state.errorMessage!,
        onRetry: () =>
            context.read<ProjectsCubit>().loadForWorkspace(workspace.id),
      );
    }
    if (state.projects.isEmpty) {
      return RefreshIndicator(
        color: _accent,
        onRefresh: () =>
            context.read<ProjectsCubit>().loadForWorkspace(workspace.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: _EmptyProjects(onCreate: onCreate),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: () =>
          context.read<ProjectsCubit>().loadForWorkspace(workspace.id),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
        itemCount: state.projects.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final project = state.projects[index];
          return _ProjectRow(
            project: project,
            isActive: project.id == state.selectedProjectId,
            calculatedProgress: state.projectTaskProgress[project.id],
            taskSummary: state.projectTaskSummaries[project.id],
            onTap: () {
              context.read<ProjectsCubit>().selectProject(project.id);
              context.push('/projects/${project.id}', extra: project);
            },
          );
        },
      ),
    );
  }

  String _projectCount(int count) {
    final lastTwo = count % 100;
    final last = count % 10;
    final noun = lastTwo >= 11 && lastTwo <= 14
        ? 'проектов'
        : last == 1
        ? 'проект'
        : last >= 2 && last <= 4
        ? 'проекта'
        : 'проектов';
    return '$count $noun';
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.isActive,
    required this.calculatedProgress,
    required this.taskSummary,
    required this.onTap,
  });

  final ProjectModel project;
  final bool isActive;
  final int? calculatedProgress;
  final ProjectTaskSummary? taskSummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (calculatedProgress ?? project.progress)
        .clamp(0, 100)
        .toDouble();
    final status = _statusFor(project, progress);
    final cardColor = isDark
        ? colorScheme.surfaceContainerLow
        : const Color(0xFFFAFAF9);
    final textColor = isDark ? const Color(0xFFF4F4F5) : _ink;
    final mutedColor = isDark ? const Color(0xFFA4A7B0) : _secondary;
    return Semantics(
      button: true,
      selected: isActive,
      label: '${project.name}, ${status.label}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isActive
              ? Color.alphaBlend(
                  _accent.withValues(alpha: isDark ? 0.11 : 0.055),
                  cardColor,
                )
              : cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          key: Key('project-row-${project.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        project.code.isEmpty
                            ? 'БЕЗ КОДА'
                            : project.code.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                          letterSpacing: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProjectStatusBadge(status: status, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        project.name.trim().isEmpty
                            ? 'Без названия'
                            : project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          height: 1.22,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (project.isPinned) ...<Widget>[
                      const SizedBox(width: 10),
                      Icon(LucideIcons.pin, size: 15, color: mutedColor),
                    ],
                  ],
                ),
                if (project.description?.trim() case final description?
                    when description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.35,
                      color: mutedColor,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: <Widget>[
                    Icon(LucideIcons.calendar, size: 13, color: mutedColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _dateRange(project.start, project.end),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.circleCheck, size: 13, color: mutedColor),
                    const SizedBox(width: 5),
                    Text(
                      taskSummary == null
                          ? '…'
                          : '${taskSummary!.completed}/${taskSummary!.total}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 4,
                          backgroundColor: isDark
                              ? const Color(0xFF303139)
                              : const Color(0xFFE8E9ED),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${progress.round()}%',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Даты не указаны';
    return '${_date(start)} — ${_date(end)}';
  }

  _ProjectStatus _statusFor(ProjectModel project, double progress) {
    if (progress >= 100) return _ProjectStatus.completed;
    final start = project.start;
    if (start != null && start.isAfter(DateTime.now())) {
      return _ProjectStatus.pending;
    }
    return _ProjectStatus.active;
  }

  String _date(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

enum _ProjectStatus {
  active('Активный'),
  pending('В ожидании'),
  completed('Завершён');

  const _ProjectStatus(this.label);
  final String label;
}

class _ProjectStatusBadge extends StatelessWidget {
  const _ProjectStatusBadge({required this.status, required this.isDark});

  final _ProjectStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (status == _ProjectStatus.active) {
      return const SizedBox.shrink();
    }

    final foreground = switch (status) {
      _ProjectStatus.active =>
        isDark ? const Color(0xFFA9ACFF) : const Color(0xFF565A73),
      _ProjectStatus.pending =>
        isDark ? const Color(0xFFF3C96B) : const Color(0xFF80692F),
      _ProjectStatus.completed =>
        isDark ? const Color(0xFF8DD5A1) : const Color(0xFF477354),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ],
    );
  }
}

class _ProjectsLoading extends StatelessWidget {
  const _ProjectsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const _LoadingRow(),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Загрузка проекта',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _block(width: 46, height: 26),
              const SizedBox(width: 12),
              Expanded(child: _block(height: 18)),
            ],
          ),
          const SizedBox(height: 14),
          _block(width: 190, height: 12),
          const SizedBox(height: 14),
          _block(height: 3),
        ],
      ),
    );
  }

  Widget _block({double? width, required double height}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.folderKanban,
                color: _accent,
                size: 25,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'В этом workspace пока нет проектов',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Создайте первый проект, чтобы планировать работу команды.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Создать проект'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsError extends StatelessWidget {
  const _ProjectsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(LucideIcons.circleAlert, size: 28, color: _secondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: _ink),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _border),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceUnavailable extends StatelessWidget {
  const _WorkspaceUnavailable({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context) {
    if (state is WorkspaceLoading || state is WorkspaceInitial) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    final message = state is WorkspaceFailure
        ? (state as WorkspaceFailure).message
        : 'Сначала выберите workspace.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(color: _secondary),
        ),
      ),
    );
  }
}

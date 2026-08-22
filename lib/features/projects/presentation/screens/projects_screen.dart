import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Открыть меню',
              onPressed: MainShell.openDrawer,
              icon: const Icon(LucideIcons.menu, color: _ink),
            ),
            title: Text(
              'Проекты',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _ink,
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
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: _surface,
                border: Border.symmetric(
                  horizontal: BorderSide(color: _border),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    LucideIcons.panelsTopLeft,
                    size: 15,
                    color: _accent,
                  ),
                  const SizedBox(width: 8),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: state.projects.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: _border),
        itemBuilder: (_, index) => _ProjectRow(project: state.projects[index]),
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
  const _ProjectRow({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final progress = project.progress.clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  project.code.isEmpty ? '—' : project.code.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.name,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              if (project.isPinned) ...<Widget>[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.pin, size: 15, color: _secondary),
                ),
              ],
            ],
          ),
          if (project.description case final description?) ...<Widget>[
            const SizedBox(height: 9),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.45,
                color: _secondary,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              const Icon(LucideIcons.calendarDays, size: 14, color: _secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dateRange(project.start, project.end),
                  style: GoogleFonts.manrope(fontSize: 12, color: _secondary),
                ),
              ),
              Text(
                '${progress.round()}%',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 3,
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
        ],
      ),
    );
  }

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Даты не указаны';
    return '${_date(start)} — ${_date(end)}';
  }

  String _date(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _ProjectsLoading extends StatelessWidget {
  const _ProjectsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
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

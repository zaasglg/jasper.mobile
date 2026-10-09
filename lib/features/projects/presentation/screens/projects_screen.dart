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
const _secondary = Color(0xFF697180);
const _border = Color(0xFFE3E6EC);
const _surface = Color(0xFFF7F8FA);
const _accent = Color(0xFF6D5FE0);

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
          backgroundColor: _surface,
          appBar: AppBar(
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
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

class _ProjectsBody extends StatefulWidget {
  const _ProjectsBody({required this.workspace, required this.onCreate});

  final WorkspaceModel workspace;
  final VoidCallback onCreate;

  @override
  State<_ProjectsBody> createState() => _ProjectsBodyState();
}

class _ProjectsBodyState extends State<_ProjectsBody> {
  final _search = TextEditingController();
  bool _listView = false;

  @override
  void didUpdateWidget(covariant _ProjectsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id) {
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
                      widget.workspace.name,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      style: GoogleFonts.manrope(fontSize: 14, color: _ink),
                      cursorColor: _accent,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Поиск проектов',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 14,
                          color: _secondary,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: _secondary,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Очистить поиск',
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                  color: _secondary,
                                ),
                                onPressed: () => setState(_search.clear),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFEEEFF3),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _accent.withValues(alpha: 0.45),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEFF3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        for (final list in [false, true])
                          IconButton(
                            key: Key(
                              list
                                  ? 'projects-list-view'
                                  : 'projects-card-view',
                            ),
                            tooltip: list ? 'Список' : 'Карточки',
                            isSelected: _listView == list,
                            onPressed: () => setState(() => _listView = list),
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(42),
                              minimumSize: const Size.square(42),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.all(6),
                              backgroundColor: _listView == list
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: _listView == list
                                  ? _accent
                                  : _secondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            icon: Icon(
                              list ? LucideIcons.list : LucideIcons.layoutGrid,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null && state.projects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Не удалось обновить проекты. Потяните список вниз, чтобы повторить.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            context.read<ProjectsCubit>().loadForWorkspace(widget.workspace.id),
      );
    }
    if (state.projects.isEmpty) {
      return RefreshIndicator(
        color: _accent,
        onRefresh: () =>
            context.read<ProjectsCubit>().loadForWorkspace(widget.workspace.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: _EmptyProjects(onCreate: widget.onCreate),
            ),
          ],
        ),
      );
    }
    final query = _search.text.trim().toLowerCase();
    final projects = state.projects.where((project) {
      return '${project.name} ${project.code} ${project.description ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
    if (projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.search, color: _secondary, size: 28),
              const SizedBox(height: 12),
              const Text(
                'Проекты не найдены',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 6),
              const Text(
                'Попробуйте другое название или код проекта.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                }),
                child: const Text('Сбросить поиск'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: () =>
          context.read<ProjectsCubit>().loadForWorkspace(widget.workspace.id),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
        itemCount: projects.length,
        separatorBuilder: (_, _) => _listView
            ? const Divider(height: 1, color: _border)
            : const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final project = projects[index];
          return _ProjectRow(
            compact: _listView,
            project: project,
            isActive: project.id == state.selectedProjectId,
            calculatedProgress: state.projectTaskProgress[project.id],
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
    required this.onTap,
    this.compact = false,
  });

  final bool compact;
  final ProjectModel project;
  final bool isActive;
  final int? calculatedProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (calculatedProgress ?? project.progress)
        .clamp(0, 100)
        .toDouble();
    if (compact) {
      return _CompactProjectRow(
        project: project,
        isActive: isActive,
        progress: progress,
        onTap: onTap,
      );
    }
    final cardColor = isDark ? colorScheme.surfaceContainerLow : Colors.white;
    final textColor = isDark ? const Color(0xFFF4F4F5) : _ink;
    final mutedColor = isDark ? const Color(0xFFA4A7B0) : _secondary;
    return Semantics(
      button: true,
      selected: isActive,
      label: project.name,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accent.withValues(alpha: 0.45) : _border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('project-row-${project.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          project.code.isEmpty
                              ? 'ПРОЕКТ'
                              : project.code.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
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
                            fontSize: 17,
                            height: 1.3,
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Выполнено',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${progress.round()}%',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? const Color(0xFF303139)
                                : const Color(0xFFE8E9ED),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _accent,
                            ),
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
      ),
    );
  }

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Даты не указаны';
    if (start == null) return 'До ${_date(end)}';
    if (end == null) return 'С ${_date(start)}';
    return '${_date(start)} — ${_date(end)}';
  }

  String _date(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _CompactProjectRow extends StatelessWidget {
  const _CompactProjectRow({
    required this.project,
    required this.isActive,
    required this.progress,
    required this.onTap,
  });
  final ProjectModel project;
  final bool isActive;
  final double progress;
  final VoidCallback onTap;

  String _date(DateTime? date) => date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final dates = project.start == null && project.end == null
        ? 'Даты не указаны'
        : project.start == null
        ? 'До ${_date(project.end)}'
        : project.end == null
        ? 'С ${_date(project.start)}'
        : '${_date(project.start)} — ${_date(project.end)}';
    return Semantics(
      button: true,
      selected: isActive,
      label: project.name,
      child: Material(
        color: isActive ? _accent.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('project-row-${project.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.folder, size: 24, color: _accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name.trim().isEmpty
                            ? 'Без названия'
                            : project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (project.code.isNotEmpty) ...[
                        Text(
                          project.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _secondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        dates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: _secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 42,
                  child: Column(
                    children: [
                      Text(
                        '${progress.round()}%',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 3,
                          color: _accent,
                          backgroundColor: _border,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 15,
                  color: _secondary,
                ),
              ],
            ),
          ),
        ),
      ),
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

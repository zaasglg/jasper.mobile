import 'package:jospar/core/localization/app_translations.dart';
import '../widgets/project_drag.dart';
import '../utils/project_tree.dart';
import '../../domain/entities/project_model.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kanban/presentation/widgets/board_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../workspaces/domain/entities/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';
import '../widgets/create_project_sheet.dart';

Color _ink(BuildContext context) => AppColors.of(context).ink;
const _secondary = BoardStyle.metadata;
Color _border(BuildContext context) => AppColors.of(context).border;
const _surface = BoardStyle.canvas;
const _accent = AppColors.accent;

const _projectCovers = [
  (base: Color(0xFFEFECFA), ink: Color(0xFF7868B3)),
  (base: Color(0xFFEAF1FA), ink: Color(0xFF577EAD)),
  (base: Color(0xFFEAF3EF), ink: Color(0xFF50877C)),
  (base: Color(0xFFFAEEE7), ink: Color(0xFFB27C60)),
];
int _projectCoverSeed(String id) =>
    id.codeUnits.fold<int>(0, (sum, unit) => sum * 31 + unit) & 0x7fffffff;

Key? _dragPreviewKey(BuildContext context, String id) =>
    ProjectDragScope.previewOf(context)?.keyFor(id);

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, workspaceState) {
        final workspace = workspaceState is WorkspaceLoaded
            ? workspaceState.selected
            : null;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: isDark
              ? BoardStyle.background(context)
              : const Color(0xFFF8F9FC),
          appBar: DashboardAppBar(
            pageTitle: 'Проекты',
            pageActions: [
              _ProjectPressFeedback(
                enabled: workspace != null,
                child: IconButton(
                  tooltip: tr(context, 'Архив проектов'),
                  onPressed: workspace == null
                      ? null
                      : () async {
                          final cubit = context.read<ProjectsCubit>();
                          await context.push(
                            '/archives/projects?workspaceId=${Uri.encodeQueryComponent(workspace.id)}',
                          );
                          await cubit.loadForWorkspace(
                            workspace.id,
                            refresh: true,
                          );
                        },
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(40),
                    minimumSize: const Size.square(40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    backgroundColor: isDark
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : Colors.white,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    side: BorderSide(color: _border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.archive,
                    size: AppIconSizes.standard,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ProjectPressFeedback(
                enabled: workspace != null,
                child: FilledButton.icon(
                  key: const Key('create_project_button'),
                  onPressed: workspace == null
                      ? null
                      : () => showCreateProjectFlow(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _border(context),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    fixedSize: const Size.fromHeight(40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: Text(tr(context, 'Создать')),
                  icon: const Icon(
                    LucideIcons.plus,
                    size: AppIconSizes.standard,
                  ),
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
  final _dragActive = ValueNotifier(false);
  final _dragPreview = ProjectDragPreview();
  bool _listView = true;

  @override
  void didUpdateWidget(covariant _ProjectsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id) {
      _dragPreview.finish();
      _search.clear();
    }
  }

  @override
  void dispose() {
    _dragPreview.dispose();
    _dragActive.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProjectDragScope(
      active: _dragActive,
      preview: _dragPreview,
      child: ListenableBuilder(
        listenable: _dragPreview,
        builder: (context, _) => _buildProjects(context),
      ),
    );
  }

  Widget _buildProjects(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        return Column(
          children: <Widget>[
            _ProjectsToolbar(
              controller: _search,
              projectCount: buildProjectTree(state.projects).length,
              listView: _listView,
              onSearchChanged: (_) => setState(() {}),
              onClear: () => setState(_search.clear),
              onViewChanged: (value) => setState(() => _listView = value),
            ),
            if (state.errorMessage != null && state.projects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tr(
                    context,
                    'Не удалось обновить проекты. Потяните список вниз, чтобы повторить.',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const ProjectRootDrop(),
            if (state.isMoving) const LinearProgressIndicator(minHeight: 2),
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
        onRetry: () => context.read<ProjectsCubit>().loadForWorkspace(
          widget.workspace.id,
          refresh: true,
        ),
      );
    }
    if (state.projects.isEmpty) {
      return RefreshIndicator(
        color: _accent,
        onRefresh: () => context.read<ProjectsCubit>().loadForWorkspace(
          widget.workspace.id,
          refresh: true,
        ),
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
    final projects = buildProjectTree(
      _dragPreview.projects ?? state.projects,
    ).where((project) => projectMatchesQuery(project, query)).toList();
    if (projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.search,
                color: _secondary,
                size: AppIconSizes.standard,
              ),
              const SizedBox(height: 12),
              Text(
                tr(context, 'Проекты не найдены'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                tr(context, 'Попробуйте другое название или код проекта.'),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                }),
                child: Text(tr(context, 'Сбросить поиск')),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: () => context.read<ProjectsCubit>().loadForWorkspace(
        widget.workspace.id,
        refresh: true,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = (constraints.maxWidth / (scale > 1.3 ? 280 : 170))
              .floor()
              .clamp(1, 5);
          final bottom = MediaQuery.paddingOf(context).bottom + AppSpacing.xl;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxs,
                  AppSpacing.md,
                  bottom,
                ),
                sliver: _listView
                    ? SliverList.separated(
                        findItemIndexCallback: (key) {
                          final index = projects.indexWhere(
                            (p) =>
                                key ==
                                ValueKey(
                                  'group-${p.id}-${widget.workspace.id}',
                                ),
                          );
                          return index < 0 ? null : index;
                        },
                        itemCount: projects.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _ProjectGroup(
                          key: ValueKey(
                            'group-${projects[index].id}-${widget.workspace.id}',
                          ),
                          project: projects[index],
                          compact: true,
                          onOpen: _openProject,
                          child: _ProjectRow(
                            compact: true,
                            project: projects[index],
                            calculatedProgress:
                                state.projectTaskProgress[projects[index].id],
                            onTap: () => _openProject(projects[index]),
                          ),
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0)
                                const SizedBox(width: AppSpacing.smMd),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      var index = column;
                                      index < projects.length;
                                      index += columns
                                    )
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.smMd,
                                        ),
                                        child: _ProjectGroup(
                                          key: ValueKey(
                                            'group-${projects[index].id}-${widget.workspace.id}',
                                          ),
                                          project: projects[index],
                                          compact: false,
                                          onOpen: _openProject,
                                          child: _ProjectRow(
                                            project: projects[index],
                                            calculatedProgress:
                                                state
                                                    .projectTaskProgress[projects[index]
                                                    .id],
                                            onTap: () =>
                                                _openProject(projects[index]),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openProject(ProjectModel project) {
    context.read<ProjectsCubit>().selectProject(project.id);
    context.push('/projects/${project.id}', extra: project);
  }
}

class _ProjectsToolbar extends StatelessWidget {
  const _ProjectsToolbar({
    required this.controller,
    required this.projectCount,
    required this.listView,
    required this.onSearchChanged,
    required this.onClear,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final int projectCount;
  final bool listView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? colors.surfaceContainerLow : Colors.white;
    final borderColor = dark ? colors.outlineVariant : const Color(0xFFE8EAF0);
    final activeBg = dark
        ? _accent.withValues(alpha: 0.22)
        : AppColors.of(context).outgoingMessage;
    final activeFg = dark ? colors.primary : _accent;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _accent, width: 1.5),
    );

    final search = TextField(
      key: const Key('projects-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      style: AppTypography.body(context)?.copyWith(color: colors.onSurface),
      cursorColor: _accent,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: tr(context, 'Поиск проектов'),
        hintStyle: AppTypography.body(
          context,
        )?.copyWith(color: colors.onSurfaceVariant),
        prefixIcon: Icon(
          LucideIcons.search,
          size: AppIconSizes.standard,
          color: colors.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('projects-search-clear'),
                tooltip: tr(context, 'Очистить поиск'),
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
              ),
        filled: true,
        fillColor: surface,
        hoverColor: colors.onSurface.withValues(alpha: .04),
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smMd,
          vertical: AppSpacing.smMd,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
      ),
    );

    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            tr(context, 'Все проекты'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: activeBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '$projectCount',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activeFg,
            ),
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final list in [false, true]) ...[
          if (list) const SizedBox(width: 4),
          IconButton(
            key: Key(list ? 'projects-list-view' : 'projects-card-view'),
            tooltip: list ? tr(context, 'Список') : tr(context, 'Карточки'),
            isSelected: listView == list,
            onPressed: () => onViewChanged(list),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(38),
              minimumSize: const Size.square(38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              backgroundColor: listView == list ? activeBg : Colors.transparent,
              foregroundColor: listView == list
                  ? activeFg
                  : colors.onSurfaceVariant,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              list ? LucideIcons.list : LucideIcons.layoutGrid,
              size: AppIconSizes.standard,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: search,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.smMd,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleRow,
                    const SizedBox(height: AppSpacing.xs),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleRow),
                  const SizedBox(width: AppSpacing.sm),
                  actions,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectGroup extends StatefulWidget {
  const _ProjectGroup({
    super.key,
    required this.project,
    required this.compact,
    required this.onOpen,
    required this.child,
  });

  final ProjectModel project;
  final bool compact;
  final ValueChanged<ProjectModel> onOpen;
  final Widget child;

  @override
  State<_ProjectGroup> createState() => _ProjectGroupState();
}

class _ProjectGroupState extends State<_ProjectGroup> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ProjectGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project.children.length > oldWidget.project.children.length) {
      _expanded = true;
    }
  }

  Widget _subproject(ProjectModel sub, int depth) {
    final colors = Theme.of(context).colorScheme;
    final progress =
        (context.read<ProjectsCubit>().state.projectTaskProgress[sub.id] ??
                sub.progress)
            .clamp(0, 100)
            .round();
    if (!widget.compact) {
      return ProjectDrag(
        key: _dragPreviewKey(context, sub.id),
        project: sub,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: Key('subproject-${sub.id}'),
              onTap: () => widget.onOpen(sub),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12 + depth.clamp(0, 2) * 8.0,
                  6,
                  12,
                  6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.cornerDownRight,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sub.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (progress == 0) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 24,
                            child: _ProjectProgress(progress: 0, small: true),
                          ),
                        ],
                      ],
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: _ProjectProgress(
                          progress: progress.toDouble(),
                          small: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            for (final child in sub.children) _subproject(child, depth + 1),
          ],
        ),
      );
    }
    return ProjectDrag(
      key: _dragPreviewKey(context, sub.id),
      project: sub,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: Key('subproject-${sub.id}'),
            onTap: () => widget.onOpen(sub),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  38 + depth.clamp(0, 3) * 12.0,
                  4,
                  16,
                  4,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.cornerDownRight,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sub.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: progress > 0 ? 68 : 30,
                      child: _ProjectProgress(
                        progress: progress.toDouble(),
                        small: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final child in sub.children) _subproject(child, depth + 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = projectDescendants(widget.project).length;
    final Widget section = count == 0
        ? const SizedBox.shrink()
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
              Semantics(
                expanded: _expanded,
                child: InkWell(
                  key: Key('toggle-subprojects-${widget.project.id}'),
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _expanded
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRight,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tr(context, 'Подпроекты'),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· $count',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_expanded)
                for (final sub in widget.project.children) _subproject(sub, 0),
            ],
          );
    final cover =
        _projectCovers[_projectCoverSeed(widget.project.id) %
            _projectCovers.length];
    final tabColor = dark
        ? Color.alphaBlend(
            cover.ink.withValues(alpha: .18),
            colors.surfaceContainerLow,
          )
        : cover.base;
    return Material(
      color: dark ? colors.surfaceContainerLow : Colors.white,
      shape: _ProjectFolderBorder(
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 10,
            width: double.infinity,
            child: ColoredBox(color: tabColor),
          ),
          widget.child,
          section,
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.calculatedProgress,
    required this.onTap,
    this.compact = false,
  });

  final bool compact;
  final ProjectModel project;
  final int? calculatedProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ProjectDrag(
    key: _dragPreviewKey(context, project.id),
    project: project,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (calculatedProgress ?? project.progress)
        .clamp(0, 100)
        .toDouble();
    if (compact) {
      return _CompactProjectRow(
        project: project,
        progress: progress,
        onTap: onTap,
      );
    }
    final variant = _projectCoverSeed(project.id);
    final cover = _projectCovers[variant % _projectCovers.length];
    final headerBg = isDark
        ? Color.alphaBlend(
            cover.ink.withValues(alpha: .18),
            colorScheme.surfaceContainerLow,
          )
        : cover.base;
    final iconColor = isDark
        ? Color.lerp(cover.ink, Colors.white, .4)!
        : cover.ink;
    final iconBg = isDark
        ? cover.ink.withValues(alpha: .18)
        : Colors.white.withValues(alpha: .82);
    return Semantics(
      button: true,
      label: tr(context, "{p0}, выполнено {p1} процентов", {
        'p0': project.name,
        'p1': progress.round(),
      }),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('project-row-${project.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 58,
                color: headerBg,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? .08 : .7,
                          ),
                        ),
                      ),
                      child: Icon(
                        LucideIcons.folder,
                        color: iconColor,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    _ProjectQuickActions(project: project),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectWorkspaceLabel(project: project),
                    Text(
                      project.name.trim().isEmpty
                          ? tr(context, 'Без названия')
                          : project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProjectProgress(progress: progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectProgress extends StatelessWidget {
  const _ProjectProgress({required this.progress, this.small = false});

  final double progress;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = progress == 100
        ? AppColors.of(context).success
        : progress == 0
        ? colors.onSurfaceVariant
        : _accent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (progress > 0) ...[
          Expanded(
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: small ? 3 : 4,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          '${progress.round()}%',
          style: GoogleFonts.inter(
            fontSize: small ? 10 : 12,
            fontWeight: progress > 0 ? FontWeight.w600 : FontWeight.w400,
            fontFeatures: [const FontFeature.tabularFigures()],
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProjectWorkspaceLabel extends StatelessWidget {
  const _ProjectWorkspaceLabel({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          if (state is! WorkspaceLoaded ||
              state.effectiveSelectedIds.length < 2) {
            return const SizedBox.shrink();
          }
          final workspace = state.workspaces
              .where((w) => w.id == project.workspaceId)
              .firstOrNull;
          if (workspace == null) return const SizedBox.shrink();
          final name = workspace.name.trim().isEmpty
              ? tr(context, 'Без названия')
              : workspace.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: name,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(
                        int.tryParse(
                              (workspace.color ?? '').replaceFirst('#', ''),
                              radix: 16,
                            )?.toUnsigned(32) ??
                            0x6D5FE0,
                      ).withAlpha(255),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      name,
                      key: Key('project-workspace-${project.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _ProjectQuickActions extends StatelessWidget {
  const _ProjectQuickActions({required this.project});
  final ProjectModel project;

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action();
    if (context.mounted && error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select(
      (ProjectsCubit cubit) =>
          cubit.state.isUpdating ||
          cubit.state.isLoading ||
          cubit.state.isMoving ||
          cubit.state.isCreating,
    );
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppColors.of(context);
    final actions = [
      (
        id: 'edit',
        label: 'Редактировать проект',
        icon: LucideIcons.pencil,
        run: () async {
          final cubit = context.read<ProjectsCubit>();
          await context.push('/manage/projects/${project.id}');
          if (!cubit.isClosed) {
            await cubit.loadForWorkspace(project.workspaceId, refresh: true);
          }
        },
      ),
      (
        id: 'pin',
        label: project.isPinned ? 'Открепить проект' : 'Закрепить проект',
        icon: LucideIcons.pin,
        run: () async {
          final cubit = context.read<ProjectsCubit>();
          await _run(
            context,
            () => cubit.setPinned(project.id, !project.isPinned),
          );
        },
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Builder(
            builder: (context) {
              final action = actions[i];
              final isPinned = action.id == 'pin' && project.isPinned;
              return IconButton(
                key: Key('project-${action.id}-${project.id}'),
                tooltip: action.label,
                onPressed: busy ? null : action.run,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(30),
                  minimumSize: const Size.square(30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: isPinned ? _accent : colors.onSurfaceVariant,
                  backgroundColor: isPinned
                      ? palette.outgoingMessage
                      : (isDark
                            ? colors.surfaceContainerHighest.withValues(
                                alpha: .6,
                              )
                            : Colors.white.withValues(alpha: .86)),
                  side: BorderSide(
                    color: isPinned
                        ? _accent.withValues(alpha: .28)
                        : (isDark
                              ? Colors.white.withValues(alpha: .08)
                              : Colors.black.withValues(alpha: .06)),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: Icon(action.icon, size: 15),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ProjectFolderBorder extends OutlinedBorder {
  const _ProjectFolderBorder({super.side});

  Path _outline(Rect rect) {
    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;
    final tab = (rect.width * .26).clamp(54.0, 88.0);
    return Path()
      ..moveTo(l + 14, t)
      ..lineTo(l + tab, t)
      ..quadraticBezierTo(l + tab + 4, t, l + tab + 7, t + 4)
      ..lineTo(l + tab + 13, t + 10)
      ..lineTo(r - 14, t + 10)
      ..quadraticBezierTo(r, t + 10, r, t + 24)
      ..lineTo(r, b - 14)
      ..quadraticBezierTo(r, b, r - 14, b)
      ..lineTo(l + 14, b)
      ..quadraticBezierTo(l, b, l, b - 14)
      ..lineTo(l, t + 14)
      ..quadraticBezierTo(l, t, l + 14, t)
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(side.width));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.solid && side.width > 0) {
      canvas.drawPath(_outline(rect.deflate(side.width / 2)), side.toPaint());
    }
  }

  @override
  _ProjectFolderBorder copyWith({BorderSide? side}) =>
      _ProjectFolderBorder(side: side ?? this.side);
  @override
  _ProjectFolderBorder scale(double t) =>
      _ProjectFolderBorder(side: side.scale(t));
}

class _CompactProjectRow extends StatelessWidget {
  const _CompactProjectRow({
    required this.project,
    required this.progress,
    required this.onTap,
  });
  final ProjectModel project;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seed = _projectCoverSeed(project.id);
    final cover = _projectCovers[seed % _projectCovers.length];
    final background = isDark
        ? Color.alphaBlend(
            cover.ink.withValues(alpha: .18),
            colorScheme.surfaceContainerLow,
          )
        : cover.base;

    return _ProjectPressFeedback(
      pressedScale: .99,
      child: Semantics(
        button: true,
        label: project.name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('project-row-${project.id}'),
            splashColor: _accent.withValues(alpha: 0.10),
            highlightColor: _accent.withValues(alpha: 0.06),
            hoverColor: _accent.withValues(alpha: 0.04),
            onTap: onTap,
            child: ColoredBox(
              color: background,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? cover.ink.withValues(alpha: .18)
                            : Colors.white.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.folder,
                        size: 18,
                        color: isDark
                            ? Color.lerp(cover.ink, Colors.white, .4)!
                            : cover.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ProjectWorkspaceLabel(project: project),
                          Text(
                            project.name.trim().isEmpty
                                ? tr(context, 'Без названия')
                                : project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 76,
                      child: _ProjectProgress(progress: progress, small: true),
                    ),
                    const SizedBox(width: 10),
                    _ProjectQuickActions(project: project),
                  ],
                ),
              ),
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
      label: tr(context, 'Загрузка проекта'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).canvas,
          borderRadius: BorderRadius.circular(16),
        ),
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
                size: AppIconSizes.standard,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr(context, 'В этом workspace пока нет проектов'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _ink(context),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              tr(
                context,
                'Создайте первый проект, чтобы планировать работу команды.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus, size: AppIconSizes.standard),
              label: Text(tr(context, 'Создать проект')),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
            const Icon(
              LucideIcons.circleAlert,
              size: AppIconSizes.standard,
              color: _secondary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _ink(context)),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _border(context)),
              ),
              child: Text(tr(context, 'Повторить')),
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
          style: GoogleFonts.inter(color: _secondary),
        ),
      ),
    );
  }
}

class _ProjectPressFeedback extends StatefulWidget {
  const _ProjectPressFeedback({
    required this.child,
    this.enabled = true,
    this.pressedScale = .96,
  });
  final Widget child;
  final bool enabled;
  final double pressedScale;
  @override
  State<_ProjectPressFeedback> createState() => _ProjectPressFeedbackState();
}

class _ProjectPressFeedbackState extends State<_ProjectPressFeedback> {
  bool _pressed = false;
  void _setPressed(bool value) {
    if (widget.enabled && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale:
            widget.enabled &&
                _pressed &&
                !media.disableAnimations &&
                !media.accessibleNavigation
            ? widget.pressedScale
            : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

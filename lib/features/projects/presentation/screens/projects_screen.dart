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

import '../../../workspaces/data/models/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../data/models/project_model.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';
import '../widgets/create_project_sheet.dart';

const _ink = AppColors.ink;
const _secondary = BoardStyle.metadata;
const _border = AppColors.border;
const _surface = BoardStyle.canvas;
const _accent = AppColors.accent;

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
          backgroundColor: BoardStyle.background(context),
          appBar: DashboardAppBar(
            pageTitle: 'Проекты',
            pageActions: [
              IconButton(
                tooltip: 'Архив проектов',
                icon: const Icon(
                  LucideIcons.archive,
                  size: AppIconSizes.standard,
                ),
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
              ),

              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: _ProjectPressFeedback(
                  enabled: workspace != null,
                  child: FilledButton.icon(
                    key: const Key('create_project_button'),
                    onPressed: workspace == null
                        ? null
                        : () => showCreateProjectFlow(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _border,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(AppSpacing.touchTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    label: const Text('Создать'),
                    icon: const Icon(
                      LucideIcons.plus,
                      size: AppIconSizes.standard,
                    ),
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
            _ProjectsToolbar(
              controller: _search,
              listView: _listView,
              onSearchChanged: (_) => setState(() {}),
              onClear: () => setState(_search.clear),
              onViewChanged: (value) => setState(() => _listView = value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _projectCount(state.projects.length),
                  style: GoogleFonts.manrope(fontSize: 12, color: _secondary),
                ),
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
              const Icon(
                LucideIcons.search,
                color: _secondary,
                size: AppIconSizes.standard,
              ),
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
                        itemCount: projects.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _ProjectRow(
                          compact: true,
                          project: projects[index],
                          isActive:
                              projects[index].id == state.selectedProjectId,
                          calculatedProgress:
                              state.projectTaskProgress[projects[index].id],
                          onTap: () => _openProject(projects[index]),
                        ),
                      )
                    : SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: AppSpacing.smMd,
                          crossAxisSpacing: AppSpacing.smMd,
                          mainAxisExtent:
                              _ProjectTileStyle.height * scale.clamp(1, 2),
                        ),
                        itemCount: projects.length,
                        itemBuilder: (context, index) => _ProjectRow(
                          project: projects[index],
                          isActive:
                              projects[index].id == state.selectedProjectId,
                          calculatedProgress:
                              state.projectTaskProgress[projects[index].id],
                          onTap: () => _openProject(projects[index]),
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

class _ProjectsToolbar extends StatelessWidget {
  const _ProjectsToolbar({
    required this.controller,
    required this.listView,
    required this.onSearchChanged,
    required this.onClear,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final bool listView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? colors.surfaceContainerLow : AppColors.canvas;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide.none,
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
        hintText: 'Поиск проектов',
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
                tooltip: 'Очистить поиск',
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
        focusedBorder: border,
      ),
    );
    final toggle = Semantics(
      label: 'Вид проектов',
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final list in [false, true]) ...[
              IconButton(
                key: Key(list ? 'projects-list-view' : 'projects-card-view'),
                tooltip: list ? 'Список' : 'Карточки',
                isSelected: listView == list,
                onPressed: () => onViewChanged(list),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(AppSpacing.touchTarget),
                  minimumSize: const Size.square(AppSpacing.touchTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(AppSpacing.smMd),
                  backgroundColor: listView == list
                      ? _accent.withValues(alpha: dark ? .24 : .1)
                      : Colors.transparent,
                  foregroundColor: listView == list
                      ? (dark ? colors.primary : _accent)
                      : colors.onSurfaceVariant,
                  shape: const RoundedRectangleBorder(),
                ),
                icon: Icon(
                  list ? LucideIcons.list : LucideIcons.layoutGrid,
                  size: AppIconSizes.standard,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.smMd,
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
                search,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: toggle),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: AppSpacing.smMd),
              toggle,
            ],
          );
        },
      ),
    );
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
    return Semantics(
      button: true,
      selected: isActive,
      label: '${project.name}, выполнено ${progress.round()} процентов',
      child: Material(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: isActive ? _accent : colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('project-row-${project.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: _accent,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.smMd),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            LucideIcons.columns3,
                            color: AppColors.onAccent,
                            size: AppSpacing.xl,
                          ),
                        ),
                        if (project.isPinned)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              LucideIcons.pin,
                              size: AppIconSizes.standard,
                              color: AppColors.onAccent,
                            ),
                          ),
                        if (isActive)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              'Текущий',
                              style: AppTypography.caption(context)?.copyWith(
                                color: AppColors.onAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.smMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name.trim().isEmpty
                          ? 'Без названия'
                          : project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Выполнено',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                              context,
                            )?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${progress.round()}%',
                          style: AppTypography.caption(
                            context,
                          )?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: AppSpacing.xs,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: progress == 100 ? AppColors.success : _accent,
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
}

abstract final class _ProjectTileStyle {
  static const height = 208.0;
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: project.name,
      child: _ProjectPressFeedback(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: isActive
                  ? _accent.withValues(alpha: .28)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            key: Key('project-row-${project.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      LucideIcons.folder,
                      size: AppIconSizes.standard,
                      color: _accent,
                    ),
                  ),
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
                            color: Theme.of(context).colorScheme.onSurface,
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
                            color: _accent,
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
                    size: AppIconSizes.standard,
                    color: _secondary,
                  ),
                ],
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
      label: 'Загрузка проекта',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
              icon: const Icon(LucideIcons.plus, size: AppIconSizes.standard),
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
            const Icon(
              LucideIcons.circleAlert,
              size: AppIconSizes.standard,
              color: _secondary,
            ),
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

class _ProjectPressFeedback extends StatefulWidget {
  const _ProjectPressFeedback({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
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
            ? .96
            : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

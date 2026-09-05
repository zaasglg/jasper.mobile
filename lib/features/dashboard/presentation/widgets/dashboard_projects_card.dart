import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../projects/data/models/project_model.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../projects/presentation/cubit/projects_state.dart';

class DashboardProjectsCard extends StatelessWidget {
  const DashboardProjectsCard({super.key});

  static const Color _ink = Color(0xFF252525);
  static const Color _muted = Color(0xFF787774);
  static const Color _accent = Color(0xFF6257C7);
  static const Color _border = Color(0xFFEAEAE8);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        return Container(
          key: const Key('dashboard-projects-card'),
          constraints: const BoxConstraints(minHeight: 396),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _CardHeader(onTap: () => context.go('/projects')),
              const Divider(height: 1, color: _border),
              _content(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, ProjectsState state) {
    if (state.isLoading && state.projects.isEmpty) {
      return const _LoadingProjects();
    }
    if (state.errorMessage != null && state.projects.isEmpty) {
      return _ProjectsMessage(
        icon: LucideIcons.circleAlert,
        message: state.errorMessage!,
        actionLabel: state.workspaceId == null ? null : 'Повторить',
        onAction: state.workspaceId == null
            ? null
            : () => context.read<ProjectsCubit>().loadForWorkspace(
                state.workspaceId!,
              ),
      );
    }
    if (state.projects.isEmpty) {
      return const _ProjectsMessage(
        icon: LucideIcons.folderOpen,
        message: 'В этом workspace пока нет проектов',
      );
    }

    final projects = state.projects.take(4).toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < projects.length; index++) ...<Widget>[
          _ProjectProgressRow(
            project: projects[index],
            calculatedProgress: state.projectTaskProgress[projects[index].id],
            colorIndex: index,
            onTap: () {
              context.read<ProjectsCubit>().selectProject(projects[index].id);
              context.go('/projects');
            },
          ),
          if (index != projects.length - 1)
            const Divider(height: 1, color: _border),
        ],
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            const Icon(
              LucideIcons.folderKanban,
              size: 20,
              color: Color(0xFF77736F),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Проекты',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DashboardProjectsCard._ink,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('dashboard-projects-open-button'),
              onPressed: onTap,
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                foregroundColor: DashboardProjectsCard._ink,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                textStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: const Icon(LucideIcons.arrowRight, size: 19),
              label: const Text('Задачи'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectProgressRow extends StatelessWidget {
  const _ProjectProgressRow({
    required this.project,
    required this.calculatedProgress,
    required this.colorIndex,
    required this.onTap,
  });

  final ProjectModel project;
  final int? calculatedProgress;
  final int colorIndex;
  final VoidCallback onTap;

  static const List<(Color, Color)> _colors = <(Color, Color)>[
    (Color(0xFFF7DEDF), Color(0xFF9B3437)),
    (Color(0xFFF1F3D9), Color(0xFF7D901F)),
    (Color(0xFFDCF3E4), Color(0xFF24984A)),
    (Color(0xFFDDEDF5), Color(0xFF28789D)),
  ];

  @override
  Widget build(BuildContext context) {
    final progress = (calculatedProgress ?? project.progress)
        .clamp(0, 100)
        .toDouble();
    final colors = _colors[colorIndex % _colors.length];
    final title = project.name.trim().isEmpty
        ? project.code.trim()
        : project.name.trim();

    return Semantics(
      button: true,
      label: '$title, ${progress.round()} процентов',
      child: InkWell(
        key: Key('dashboard-project-${project.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.$1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _initial(title),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.$2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Без названия' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DashboardProjectsCard._ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${progress.round()}%',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: DashboardProjectsCard._muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 3,
                        backgroundColor: const Color(0xFFF2F2F1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DashboardProjectsCard._accent,
                        ),
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

  String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed.characters.first.toUpperCase();
  }
}

class _ProjectsMessage extends StatelessWidget {
  const _ProjectsMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 26, color: const Color(0xFF9295A2)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.4,
                  color: DashboardProjectsCard._muted,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingProjects extends StatelessWidget {
  const _LoadingProjects();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _LoadingRow(),
        Divider(height: 1, color: DashboardProjectsCard._border),
        _LoadingRow(),
        Divider(height: 1, color: DashboardProjectsCard._border),
        _LoadingRow(),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 150,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEEF1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1F3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

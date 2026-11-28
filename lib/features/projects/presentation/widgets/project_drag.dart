import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/project_model.dart';
import '../cubit/projects_cubit.dart';
import '../utils/project_move.dart';
import '../utils/project_tree.dart';

class ProjectDragPreview extends ChangeNotifier {
  final _keys = <String, GlobalKey>{};
  GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'project-drag-$id'));
  List<ProjectModel>? _snapshot;
  List<ProjectModel>? projects;
  String? sourceId;
  ProjectMove? move;
  Offset? _lastPointer;

  void start(List<ProjectModel> snapshot, String id) {
    _snapshot = snapshot;
    sourceId = id;
    move = null;
    _lastPointer = null;
  }

  void hover(ProjectMove next, Offset pointer) {
    if (_snapshot == null || sourceId == null || next == move) return;
    // Reflow alone must not change the target underneath a stationary pointer.
    if (_lastPointer != null && (pointer - _lastPointer!).distance < 6) return;
    _lastPointer = pointer;
    move = next;
    projects = applyProjectMove(_snapshot!, sourceId!, next);
    notifyListeners();
  }

  void finish() {
    if (_snapshot == null) return;
    _snapshot = null;
    projects = null;
    sourceId = null;
    move = null;
    _lastPointer = null;
    notifyListeners();
  }
}

class ProjectDragScope extends InheritedWidget {
  const ProjectDragScope({
    super.key,
    required this.active,
    this.preview,
    required super.child,
  });
  final ValueNotifier<bool> active;
  final ProjectDragPreview? preview;
  static ValueNotifier<bool> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProjectDragScope>()!.active;
  static ProjectDragPreview? previewOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProjectDragScope>()?.preview;
  @override
  bool updateShouldNotify(ProjectDragScope oldWidget) =>
      active != oldWidget.active || preview != oldWidget.preview;
}

Future<void> _move(
  BuildContext context,
  ProjectModel source,
  ProjectMove move,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await context.read<ProjectsCubit>().moveProject(
    source.id,
    move,
  );
  if (context.mounted && error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}

class ProjectDrag extends StatefulWidget {
  const ProjectDrag({super.key, required this.project, required this.child});
  final ProjectModel project;
  final Widget child;
  @override
  State<ProjectDrag> createState() => _ProjectDragState();
}

class _ProjectDragState extends State<ProjectDrag> {
  String? _placement;
  bool _mouse = false;
  Timer? _scrollTimer;
  double _scrollDelta = 0;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _autoScroll(DragUpdateDetails details) {
    final scroll = Scrollable.maybeOf(context);
    if (scroll == null) return;
    final box = scroll.context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final y = box.globalToLocal(details.globalPosition).dy;
    _scrollDelta = y < 60
        ? -6
        : y > box.size.height - 60
        ? 6
        : 0;
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !scroll.position.hasPixels || _scrollDelta == 0) return;
      final position = scroll.position;
      position.jumpTo(
        (position.pixels + _scrollDelta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  ProjectModel _current(ProjectModel project) {
    final roots = buildProjectTree(
      context.read<ProjectsCubit>().state.projects,
    );
    return [
          for (final root in roots) root,
          for (final root in roots) ...projectDescendants(root),
        ].where((p) => p.id == project.id).firstOrNull ??
        project;
  }

  String _zone(Offset offset) {
    final box = context.findRenderObject() as RenderBox;
    final y = box.globalToLocal(offset).dy / box.size.height;
    return y >= .28 && y <= .72
        ? 'inside'
        : y < .5
        ? 'before'
        : 'after';
  }

  @override
  Widget build(BuildContext context) {
    final active = ProjectDragScope.of(context);
    final source = _current(widget.project);
    final preview = ProjectDragScope.previewOf(context);
    final busy = context.select(
      (ProjectsCubit cubit) =>
          cubit.state.isUpdating ||
          cubit.state.isMoving ||
          cubit.state.isLoading ||
          cubit.state.isCreating,
    );
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = colors.accent;
    final isSubproject = source.parentId != null;
    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        width: 236,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? colors.subtleSurface : Colors.white,
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.outgoingMessage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSubproject ? LucideIcons.hash : LucideIcons.folder,
                size: 15,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.gripVertical, size: 15, color: colors.muted),
          ],
        ),
      ),
    );
    final target = DragTarget<ProjectModel>(
      onWillAcceptWithDetails: (details) =>
          !busy &&
          ((details.data.id == source.id && preview?.move != null) ||
              const ['before', 'inside', 'after'].any(
                (zone) =>
                    projectMove(_current(details.data), source, zone) != null,
              )),
      onMove: (details) {
        final zone = _zone(details.offset);
        final valid =
            !busy && projectMove(_current(details.data), source, zone) != null;
        final next = valid ? zone : null;
        if (valid) {
          preview?.hover(
            projectMove(_current(details.data), source, zone)!,
            details.offset,
          );
        }
        if (_placement != next) setState(() => _placement = next);
      },
      onLeave: (_) => setState(() => _placement = null),
      onAcceptWithDetails: (details) {
        final requested = projectMove(
          _current(details.data),
          source,
          _zone(details.offset),
        );
        final move = details.data.id == source.id
            ? preview?.move
            : requested == null
            ? null
            : preview?.move ?? requested;
        setState(() => _placement = null);
        if (!busy && move != null) _move(context, details.data, move);
      },
      builder: (context, candidates, rejected) => Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_placement == 'inside')
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 110 ||
                          constraints.maxHeight < 44) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.cornerDownRight,
                                  size: 12,
                                  color: colors.onAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tr(context, 'Внутрь'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onAccent,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_placement == 'before')
            Positioned(
              left: 0,
              right: 0,
              top: -4,
              child: IgnorePointer(
                child: _InsertionLine(
                  color: accent,
                  textColor: colors.onAccent,
                  label: tr(context, 'Сюда'),
                ),
              ),
            ),
          if (_placement == 'after')
            Positioned(
              left: 0,
              right: 0,
              bottom: -4,
              child: IgnorePointer(
                child: _InsertionLine(
                  color: accent,
                  textColor: colors.onAccent,
                  label: tr(context, 'Сюда'),
                ),
              ),
            ),
        ],
      ),
    );
    void start() {
      preview?.start(context.read<ProjectsCubit>().state.projects, source.id);
      active.value = true;
    }

    void end(DraggableDetails _) {
      _scrollTimer?.cancel();
      _scrollTimer = null;
      active.value = false;
      preview?.finish();
      if (mounted) setState(() => _placement = null);
    }

    return MouseRegion(
      onEnter: (event) {
        final mouse = event.kind == PointerDeviceKind.mouse;
        if (mouse != _mouse) setState(() => _mouse = mouse);
      },
      child: _mouse
          ? Draggable<ProjectModel>(
              data: source,
              maxSimultaneousDrags: busy ? 0 : 1,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              onDragStarted: start,
              onDragUpdate: _autoScroll,
              onDragEnd: end,
              childWhenDragging: Opacity(opacity: .35, child: target),
              child: target,
            )
          : LongPressDraggable<ProjectModel>(
              data: source,
              maxSimultaneousDrags: busy ? 0 : 1,
              delay: const Duration(milliseconds: 350),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              onDragStarted: start,
              onDragUpdate: _autoScroll,
              onDragEnd: end,
              childWhenDragging: Opacity(opacity: .35, child: target),
              child: target,
            ),
    );
  }
}

class ProjectRootDrop extends StatelessWidget {
  const ProjectRootDrop({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ProjectDragScope.of(context),
    builder: (context, active, _) => !active
        ? const SizedBox.shrink()
        : DragTarget<ProjectModel>(
            onWillAcceptWithDetails: (details) =>
                !context.read<ProjectsCubit>().state.isMoving,
            onMove: (details) => ProjectDragScope.previewOf(context)?.hover((
              workspaceId: details.data.workspaceId,
              parentId: null,
              anchorId: null,
              placement: 'append',
            ), details.offset),
            onAcceptWithDetails: (details) => _move(context, details.data, (
              workspaceId: details.data.workspaceId,
              parentId: null,
              anchorId: null,
              placement: 'append',
            )),
            builder: (context, candidates, rejected) {
              final colors = AppColors.of(context);
              final isHovered = candidates.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                key: const Key('project-root-drop'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isHovered
                      ? colors.accent.withValues(alpha: 0.14)
                      : colors.outgoingMessage,
                  border: Border.all(
                    color: isHovered
                        ? colors.accent
                        : colors.accent.withValues(alpha: 0.35),
                    width: isHovered ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.folderUp, size: 16, color: colors.accent),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'В корень проектов'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}

class _InsertionLine extends StatelessWidget {
  const _InsertionLine({
    required this.color,
    required this.textColor,
    required this.label,
  });

  final Color color;
  final Color textColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = constraints.maxWidth >= 96;
        final showDot = constraints.maxWidth >= 16;
        return Row(
          children: [
            if (showDot)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (showLabel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

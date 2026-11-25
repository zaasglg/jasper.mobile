import 'package:jospar/core/localization/app_translations.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    final accent = Theme.of(context).colorScheme.primary;
    final feedback = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: accent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.hash, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
      builder: (context, candidates, rejected) => DecoratedBox(
        decoration: BoxDecoration(
          color: _placement == 'inside' ? accent.withValues(alpha: .08) : null,
          border: _placement == 'inside'
              ? Border.all(color: accent, width: 2)
              : Border(
                  top: BorderSide(
                    color: _placement == 'before' ? accent : Colors.transparent,
                    width: 2,
                  ),
                  bottom: BorderSide(
                    color: _placement == 'after' ? accent : Colors.transparent,
                    width: 2,
                  ),
                ),
        ),
        child: widget.child,
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
            builder: (context, candidates, rejected) => Container(
              key: const Key('project-root-drop'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: candidates.isEmpty ? .04 : .15,
                ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr(context, 'В корень проектов'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
  );
}

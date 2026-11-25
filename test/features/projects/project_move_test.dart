import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/repositories/project_repository_impl.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/projects/presentation/utils/project_move.dart';
import 'package:jospar/features/projects/presentation/utils/project_tree.dart';
import 'package:jospar/features/projects/presentation/widgets/project_drag.dart';

ProjectModel project(
  String id, {
  String workspace = 'w',
  String? parent,
  List<ProjectModel> children = const [],
}) => ProjectModel(
  id: id,
  name: id,
  code: id,
  workspaceId: workspace,
  parentId: parent,
  children: children,
  start: null,
  end: null,
);

class Repository implements ProjectRepository {
  @override
  Future<void> setPinned(String id, bool pinned) async {}
  @override
  Future<void> archiveProject(String id) async {}

  List<ProjectModel> projects = [
    project('a'),
    project('b'),
    project('c', parent: 'b'),
  ];
  final moves = <(String, ProjectMove)>[];
  bool fail = false;
  int loads = 0;
  Completer<void>? pending;
  @override
  Future<List<ProjectModel>> getProjects() async {
    loads++;
    return projects;
  }

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) =>
      throw UnimplementedError();
  @override
  Future<void> moveProject(
    String id, {
    required String workspaceId,
    String? parentId,
    String? anchorId,
    required String placement,
  }) async {
    moves.add((
      id,
      (
        workspaceId: workspaceId,
        parentId: parentId,
        anchorId: anchorId,
        placement: placement,
      ),
    ));
    if (pending != null) await pending!.future;
    if (fail) throw Exception('offline');
    projects = applyProjectMove(projects, id, (
      workspaceId: workspaceId,
      parentId: parentId,
      anchorId: anchorId,
      placement: placement,
    ));
  }
}

void main() {
  test('matches web inside, sibling, root and depth restrictions', () {
    final a = project('a');
    final c = project('c', parent: 'b');
    final b = project('b', children: [c]);
    expect(projectMove(a, b, 'inside'), (
      workspaceId: 'w',
      parentId: 'b',
      anchorId: null,
      placement: 'append',
    ));
    expect(projectMove(a, c, 'before'), (
      workspaceId: 'w',
      parentId: 'b',
      anchorId: 'c',
      placement: 'before',
    ));
    expect(projectMove(c, a, 'after')?.parentId, isNull);
    expect(projectMove(a, a, 'inside'), isNull);
    expect(projectMove(b, a, 'inside'), isNull);
    expect(projectMove(a, c, 'inside'), isNull);
    expect(projectMove(b, c, 'before'), isNull);
    expect(
      projectMove(a, project('other', workspace: 'other'), 'inside'),
      isNull,
    );
    final nested = buildProjectTree([
      project('root', children: [project('nested')]),
    ]);
    expect(nested.single.children.single.parentId, 'root');
  });

  test('preview preserves descendants and clears parent when detaching', () {
    final tree = [
      project('a', children: [project('child')]),
      project('b'),
    ];
    final reordered = applyProjectMove(
      tree,
      'a',
      projectMove(tree.first, tree.last, 'after')!,
    );
    expect(reordered.map((p) => p.id), ['b', 'a']);
    expect(reordered.last.children.single.id, 'child');
    final detached = applyProjectMove(tree, 'child', (
      workspaceId: 'w',
      parentId: null,
      anchorId: 'b',
      placement: 'after',
    ));
    expect(detached.map((p) => p.id), ['a', 'b', 'child']);
    expect(detached.first.children, isEmpty);
    expect(detached.last.parentId, isNull);
    expect(tree.first.children.single.id, 'child');
  });

  test('uses the web PATCH payload including explicit null parent', () async {
    final dio = Dio();
    RequestOptions? recorded;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          recorded = options;
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {}),
          );
        },
      ),
    );
    final repository = ProjectRepositoryImpl(dio);
    await repository.moveProject(
      'a/b',
      workspaceId: 'w',
      parentId: null,
      placement: 'append',
    );
    expect(recorded!.method, 'PATCH');
    expect(recorded!.path, 'projects/a%2Fb/move');
    expect(recorded!.data, {
      'workspaceId': 'w',
      'group': 'tree',
      'parentId': null,
      'placement': 'append',
    });
    dio.close();
  });

  test(
    'serializes moves, preserves content on failure and validates cycles',
    () async {
      final repository = Repository();
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace('w');
      final before = cubit.state.projects;
      repository.pending = Completer<void>();
      final move = projectMove(project('a'), project('b'), 'inside')!;
      final pending = cubit.moveProject('a', move);
      expect(cubit.state.isMoving, isTrue);
      expect(await cubit.moveProject('a', move), isNotNull);
      expect(repository.moves.length, 1);
      repository.fail = true;
      repository.pending!.complete();
      expect(await pending, isNotNull);
      expect(cubit.state.projects, before);
      expect(cubit.state.isMoving, isFalse);
      final invalid = (
        workspaceId: 'w',
        parentId: 'c',
        anchorId: null,
        placement: 'append',
      );
      expect(await cubit.moveProject('b', invalid), isNotNull);
      expect(repository.moves.length, 1);
    },
  );

  test(
    'moves a child to root and ignores completion after workspace switch',
    () async {
      final repository = Repository();
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace('w');
      repository.pending = Completer<void>();
      final pending = cubit.moveProject('c', (
        workspaceId: 'w',
        parentId: null,
        anchorId: null,
        placement: 'append',
      ));
      await cubit.loadForWorkspace('other');
      repository.pending!.complete();
      expect(await pending, isNull);
      expect(cubit.state.workspaceId, 'other');
      expect(cubit.state.projects, isEmpty);
    },
  );

  for (final zone in ['inside', 'before', 'after']) {
    testWidgets('long press drops $zone a project', (tester) async {
      final repository = Repository();
      final cubit = ProjectsCubit(repository);
      final active = ValueNotifier(false);
      addTearDown(cubit.close);
      addTearDown(active.dispose);
      await cubit.loadForWorkspace('w');
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: ProjectDragScope(
                active: active,
                child: ListView(
                  children: [
                    ProjectDrag(
                      project: project('a'),
                      child: const SizedBox(
                        key: Key('a'),
                        height: 100,
                        child: Text('a'),
                      ),
                    ),
                    ProjectDrag(
                      project: project('b'),
                      child: const SizedBox(
                        key: Key('b'),
                        height: 100,
                        child: Text('b'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('a'))),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final rect = tester.getRect(find.byKey(const Key('b')));
      await gesture.moveTo(
        Offset(
          rect.center.dx,
          zone == 'inside'
              ? rect.center.dy
              : zone == 'before'
              ? rect.top + 5
              : rect.bottom - 5,
        ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.moves.single.$1, 'a');
      expect(
        repository.moves.single.$2.parentId,
        zone == 'inside' ? 'b' : null,
      );
      expect(
        repository.moves.single.$2.placement,
        zone == 'inside' ? 'append' : zone,
      );
      expect(repository.loads, 2);
      expect(active.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('dragging a child reveals root drop zone and detaches it', (
    tester,
  ) async {
    final repository = Repository();
    final cubit = ProjectsCubit(repository);
    final active = ValueNotifier(false);
    addTearDown(cubit.close);
    addTearDown(active.dispose);
    await cubit.loadForWorkspace('w');
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: ProjectDragScope(
              active: active,
              child: Column(
                children: [
                  const ProjectRootDrop(),
                  Expanded(
                    child: ListView(
                      children: [
                        ProjectDrag(
                          project: project('c', parent: 'b'),
                          child: const SizedBox(
                            key: Key('child'),
                            height: 100,
                            child: Text('c'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('project-root-drop')), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('child'))),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('project-root-drop'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.moves.single.$1, 'c');
    expect(repository.moves.single.$2.parentId, isNull);
    expect(find.byKey(const Key('project-root-drop')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final grid in [false, true]) {
    testWidgets(
      'live ${grid ? "grid" : "list"} preview moves before release and cancels cleanly',
      (tester) async {
        final repository = Repository();
        repository.projects = [project('a'), project('b'), project('d')];
        final cubit = ProjectsCubit(repository);
        final active = ValueNotifier(false);
        final preview = ProjectDragPreview();
        addTearDown(cubit.close);
        addTearDown(active.dispose);
        addTearDown(preview.dispose);
        await cubit.loadForWorkspace('w');
        Widget tile(ProjectModel p) => ProjectDrag(
          key: preview.keyFor(p.id),
          project: p,
          child: SizedBox(
            key: ValueKey('tile-${p.id}'),
            width: 150,
            height: 100,
            child: Text(p.name),
          ),
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              home: Scaffold(
                body: ProjectDragScope(
                  active: active,
                  preview: preview,
                  child: ListenableBuilder(
                    listenable: preview,
                    builder: (context, _) {
                      final projects = preview.projects ?? cubit.state.projects;
                      return grid
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var col = 0; col < 2; col++)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        for (
                                          var i = col;
                                          i < projects.length;
                                          i += 2
                                        )
                                          tile(projects[i]),
                                      ],
                                    ),
                                  ),
                              ],
                            )
                          : Column(
                              children: [for (final p in projects) tile(p)],
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        final initial = tester.getTopLeft(find.byKey(const ValueKey('tile-b')));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('tile-a'))),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final target = tester.getRect(find.byKey(const ValueKey('tile-b')));
        await gesture.moveTo(Offset(target.center.dx, target.bottom - 5));
        await tester.pump();
        expect(preview.projects!.map((p) => p.id), ['b', 'a', 'd']);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('tile-b'))),
          isNot(initial),
        );
        expect(repository.moves, isEmpty);
        // Leaving all drop targets cancels the preview and restores the snapshot.
        await gesture.moveTo(const Offset(700, 550));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(preview.projects, isNull);
        expect(active.value, isFalse);
        expect(repository.moves, isEmpty);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('tile-b'))),
          initial,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final nest in [false, true]) {
    testWidgets(
      'live preview ${nest ? "reparents" : "reorders"} and saves once on release',
      (tester) async {
        final repository = Repository();
        repository.projects = [project('a'), project('b')];
        repository.pending = Completer<void>();
        final cubit = ProjectsCubit(repository);
        final active = ValueNotifier(false);
        final preview = ProjectDragPreview();
        addTearDown(cubit.close);
        addTearDown(active.dispose);
        addTearDown(preview.dispose);
        await cubit.loadForWorkspace('w');
        Widget tile(ProjectModel p) => ProjectDrag(
          key: preview.keyFor(p.id),
          project: p,
          child: SizedBox(
            key: ValueKey('tile-${p.id}'),
            height: 100,
            child: Text(p.name),
          ),
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              home: Scaffold(
                body: ProjectDragScope(
                  active: active,
                  preview: preview,
                  child: ListenableBuilder(
                    listenable: preview,
                    builder: (context, _) =>
                        BlocBuilder<ProjectsCubit, ProjectsState>(
                          builder: (context, state) {
                            final projects =
                                preview.projects ?? cubit.state.projects;
                            return Column(
                              children: [
                                for (final p in projects)
                                  Column(
                                    key: ValueKey('group-${p.id}'),
                                    children: [
                                      tile(p),
                                      for (final sub in p.children) tile(sub),
                                    ],
                                  ),
                              ],
                            );
                          },
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('tile-a'))),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final target = tester.getRect(find.byKey(const ValueKey('tile-b')));
        await gesture.moveTo(
          Offset(target.center.dx, nest ? target.center.dy : target.bottom - 5),
        );
        await tester.pump();
        expect(repository.moves, isEmpty);
        if (nest) {
          expect(preview.projects!.single.id, 'b');
          expect(preview.projects!.single.children.single.id, 'a');
        } else {
          expect(preview.projects!.map((p) => p.id), ['b', 'a']);
        }
        // The placeholder under the pointer remains an accepting drop target.
        await gesture.moveTo(
          tester.getCenter(find.byKey(const ValueKey('tile-a'))),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(repository.moves, hasLength(1));
        expect(active.value, isFalse);
        expect(preview.projects, isNull);
        expect(cubit.state.isMoving, isTrue);
        if (nest) {
          expect(cubit.state.projects.single.children.single.id, 'a');
        } else {
          expect(cubit.state.projects.map((p) => p.id), ['b', 'a']);
        }
        repository.pending!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

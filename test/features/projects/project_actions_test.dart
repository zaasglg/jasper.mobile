import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/repositories/project_repository_impl.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';

ProjectModel project(String id, {List<ProjectModel> children = const []}) =>
    ProjectModel(
      id: id,
      code: id,
      name: id,
      workspaceId: 'w',
      start: null,
      end: null,
      children: children,
    );

class Repository implements ProjectRepository {
  List<ProjectModel> projects = [
    project('a'),
    project('b', children: [project('child')]),
  ];
  Completer<void>? pending;
  bool fail = false;
  int calls = 0;
  @override
  Future<List<ProjectModel>> getProjects() async => projects;
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
  }) => throw UnimplementedError();
  Future<void> wait() async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) {
      throw const ProjectException('Недостаточно прав для этого действия.');
    }
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    await wait();
    projects = [
      for (final p in projects) p.id == id ? p.copyWith(isPinned: pinned) : p,
    ];
  }

  @override
  Future<void> archiveProject(String id) async {
    await wait();
    projects = projects.where((p) => p.id != id).toList();
  }
}

void main() {
  test('pin and archive use web API contracts', () async {
    final dio = Dio();
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        },
      ),
    );
    final repository = ProjectRepositoryImpl(dio);
    await repository.setPinned('a/b', true);
    await repository.setPinned('a/b', false);
    await repository.archiveProject('a/b');
    expect(requests.map((r) => r.method), everyElement('PATCH'));
    expect(requests.first.path, 'projects/a%2Fb');
    expect(requests.first.data, {'isPinned': true});
    expect(requests[1].data, {'isPinned': false});
    expect(requests.last.path, 'projects/a%2Fb/archive');
    dio.close();
  });

  test('pin persists and moves project first; unpin updates state', () async {
    final repository = Repository();
    final cubit = ProjectsCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadForWorkspace('w');
    expect(await cubit.setPinned('b', true), isNull);
    expect(cubit.state.projects.first.id, 'b');
    expect(cubit.state.projects.first.isPinned, isTrue);
    expect(await cubit.setPinned('b', false), isNull);
    expect(cubit.state.projects.first.isPinned, isFalse);
    expect(repository.projects.last.isPinned, isFalse);
    expect(cubit.state.isUpdating, isFalse);
  });

  test(
    'archive removes subtree and clears selection after last project',
    () async {
      final repository = Repository()
        ..projects = [
          project('root', children: [project('child')]),
        ];
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace('w');
      cubit.selectProject('child');
      expect(await cubit.archiveProject('root'), isNull);
      expect(cubit.state.projects, isEmpty);
      expect(cubit.state.selectedProjectId, isNull);
      expect(cubit.state.isUpdating, isFalse);
    },
  );

  test(
    'failure preserves data, reports permissions and blocks double submit',
    () async {
      final repository = Repository()
        ..pending = Completer<void>()
        ..fail = true;
      final cubit = ProjectsCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadForWorkspace('w');
      final before = cubit.state.projects;
      final pending = cubit.setPinned('b', true);
      expect(cubit.state.isUpdating, isTrue);
      expect(await cubit.archiveProject('a'), isNotNull);
      expect(repository.calls, 1);
      repository.pending!.complete();
      expect(await pending, contains('Недостаточно прав'));
      expect(cubit.state.projects, before);
      expect(cubit.state.isUpdating, isFalse);
    },
  );

  test('late action cannot overwrite another workspace', () async {
    final repository = Repository()..pending = Completer<void>();
    final cubit = ProjectsCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadForWorkspace('w');
    final pending = cubit.setPinned('b', true);
    await cubit.loadForWorkspace('other');
    repository.pending!.complete();
    expect(await pending, isNull);
    expect(cubit.state.workspaceId, 'other');
    expect(cubit.state.projects, isEmpty);
  });
}

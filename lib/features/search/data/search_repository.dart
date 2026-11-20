import '../../inbox/data/models/inbox_task_dto.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../inbox/domain/entities/inbox_task_model.dart';
import '../../projects/data/models/project_model.dart';
import '../../projects/data/models/project_task_model.dart';

class SearchResults extends Equatable {
  const SearchResults({
    this.tasks = const [],
    this.projects = const [],
    this.inbox = const [],
    this.failedSources = const [],
  });
  final List<ProjectTaskModel> tasks;
  final List<ProjectModel> projects;
  final List<InboxTaskModel> inbox;
  final List<String> failedSources;
  bool get isEmpty => tasks.isEmpty && projects.isEmpty && inbox.isEmpty;
  @override
  List<Object?> get props => [tasks, projects, inbox, failedSources];
}

abstract interface class SearchRepository {
  Future<SearchResults> search(
    String query,
    String workspaceId, {
    CancelToken? cancelToken,
  });
}

// API reference: https://jospar.me/api/docs-json
// GET /project-tasks: search, projectIds, archived, take, skip.
class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl(this.dio);
  final Dio dio;

  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      for (final key in [
        'data',
        'items',
        'tasks',
        'projects',
        'inbox',
        'rows',
        'results',
      ]) {
        if (data[key] is List || data[key] is Map) return _items(data[key]);
      }
    }
    throw const FormatException('Некорректный ответ поиска');
  }

  @override
  Future<SearchResults> search(
    String query,
    String workspaceId, {
    CancelToken? cancelToken,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const SearchResults();
    final failures = <String>[];
    Future<List<Map<String, dynamic>>> fetch(
      String endpoint,
      String source, {
      Map<String, dynamic>? params,
    }) async {
      try {
        return _items(
          (await dio.get<dynamic>(
            endpoint,
            queryParameters: params,
            cancelToken: cancelToken,
          )).data,
        );
      } catch (error) {
        if (error is DioException && CancelToken.isCancel(error)) rethrow;
        failures.add(source);
        return [];
      }
    }

    final initial = await Future.wait([
      fetch('projects', 'Проекты'),
      fetch('inbox', 'Инбокс', params: {'archived': 0, 'sort': 1}),
    ]);
    List<ProjectModel> flatten(
      List<ProjectModel> values, [
      String parentWorkspace = '',
    ]) => [
      for (final project in values) ...[
        project.workspaceId.isEmpty
            ? project.copyWith(workspaceId: parentWorkspace)
            : project,
        ...flatten(
          project.children,
          project.workspaceId.isEmpty ? parentWorkspace : project.workspaceId,
        ),
      ],
    ];
    final projects = flatten(initial[0].map(ProjectModel.fromJson).toList())
        .where(
          (project) =>
              workspaceId.isEmpty || project.workspaceId == workspaceId,
        )
        .toList();
    final ids = projects
        .map((project) => project.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    Future<List<Map<String, dynamic>>> taskMatches(bool archived) async {
      const pageSize = 50;
      final source = archived ? 'Архив задач' : 'Задачи';
      final matches = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      var skip = 0;
      while (true) {
        final page = await fetch(
          'project-tasks',
          source,
          params: {
            'search': text,
            'projectIds': ids.join(','),
            'archived': archived,
            'take': pageSize,
            'skip': skip,
          },
        );
        if (page.isEmpty) break;
        var added = false;
        for (final item in page) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty && seenIds.add(id)) {
            matches.add(item);
            added = true;
          }
        }
        if (page.length < pageSize) break;
        // A server ignoring skip must not cause an endless search. Keep the
        // pages already received and report this source as incomplete.
        if (!added) {
          if (!failures.contains(source)) failures.add(source);
          break;
        }
        skip += page.length;
      }
      return matches;
    }

    final taskPages = ids.isEmpty
        ? <List<Map<String, dynamic>>>[]
        : await Future.wait([taskMatches(false), taskMatches(true)]);
    final tasks = <String, ProjectTaskModel>{};
    for (var page = 0; page < taskPages.length; page++) {
      for (final json in taskPages[page]) {
        final task = ProjectTaskModel.fromJson(json);
        if (task.id.isNotEmpty && ids.contains(task.projectId)) {
          tasks[task.id] = page == 1 ? task.copyWith(archived: true) : task;
        }
      }
    }
    final lower = text.toLowerCase();
    return SearchResults(
      tasks: tasks.values.toList(),
      projects: projects
          .where(
            (project) =>
                '${project.name} ${project.code}'.toLowerCase().contains(lower),
          )
          .toList(),
      inbox: initial[1]
          .map((json) => InboxTaskDto.fromJson(json).toEntity())
          .where(
            (task) =>
                !task.archived &&
                task.id.isNotEmpty &&
                '${task.title} ${task.displayId} ${task.description ?? ''}'
                    .toLowerCase()
                    .contains(lower),
          )
          .toList(),
      failedSources: failures,
    );
  }
}

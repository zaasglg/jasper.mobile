import 'models/dashboard_layout_dto.dart';
import '../../tasks/domain/utils/task_column_label.dart';
import '../../tasks/data/models/kanban_column_model.dart';
import 'package:dio/dio.dart';
import '../domain/dashboard_repository.dart';
import '../domain/entities/dashboard_layout.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.dio);
  final Dio dio;
  Options options(String workspaceId) =>
      Options(headers: {'X-Workspace-Id': workspaceId});
  @override
  Future<DashboardLayout> load(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async => DashboardLayoutDto.parse(
    (await dio.get<dynamic>(
      'dashboard/config',
      queryParameters: {'workspaceId': workspaceId},
      options: options(workspaceId),
      cancelToken: cancelToken,
    )).data,
  ).toEntity();
  @override
  Future<DashboardLayout> save(
    String workspaceId,
    DashboardLayout layout,
  ) async {
    final response = await dio.put<dynamic>(
      'dashboard/config',
      data: {
        'workspaceId': workspaceId,
        'layout': DashboardLayoutDto.fromEntity(layout).toJson(),
      },
      options: options(workspaceId),
    );
    return DashboardLayoutDto.parse(response.data).toEntity();
  }

  static List<Map<String, dynamic>> items(dynamic data) {
    if (data is Map) {
      data =
          data['data'] ??
          data['items'] ??
          data['members'] ??
          data['messages'] ??
          data['threads'];
    }
    if (data is! List) {
      throw const DashboardException('Некорректный ответ сервера');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return [];
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var skip = 0; ; skip += 100) {
      final page = items(
        (await dio.get<dynamic>(
          'project-tasks',
          queryParameters: {
            'projectIds': projectIds.join(','),
            'archived': 'false',
            'take': 100,
            'skip': skip,
          },
          options: options(workspaceId),
        )).data,
      );
      var added = 0;
      for (final row in page) {
        if (projectIds.contains(row['projectId']) &&
            seen.add(row['id'].toString())) {
          rows.add(row);
          added++;
        }
      }
      if (page.length < 100) break;
      if (added == 0) {
        throw const DashboardException('Сервер повторил страницу задач');
      }
    }
    final columnsByProject = <String, List<KanbanColumnModel>>{};
    await Future.wait(
      rows.map((t) => t['projectId'].toString()).toSet().map((id) async {
        try {
          final response = await dio.get<dynamic>(
            'kanban-columns',
            queryParameters: {'projectId': id},
            options: options(workspaceId),
          );
          columnsByProject[id] = items(response.data)
              .map(
                (raw) => KanbanColumnModel.fromJson({
                  ...raw,
                  'archived':
                      raw['archived'] == true || raw['archivedAt'] != null,
                }),
              )
              .toList();
        } on DioException {
          // A missing column list must not make all tasks unavailable.
          columnsByProject[id] = [];
        }
      }),
    );
    return [
      for (final task in rows)
        {
          ...task,
          'columnName': taskColumnLabel(
            task['status']?.toString() ?? '',
            columns: columnsByProject[task['projectId']] ?? const [],
          ),
        },
    ];
  }

  @override
  Future<dynamic> widgetData(String workspaceId, String kind) async {
    if (kind == 'activity' || kind.startsWith('activity:')) {
      final category = kind == 'activity'
          ? 'all'
          : kind.substring('activity:'.length);
      if (category != 'personal') {
        return (await dio.get<dynamic>(
          'activity-log',
          queryParameters: {
            'workspaceId': workspaceId,
            'limit': 6,
            if (category != 'all') 'category': category,
          },
          options: options(workspaceId),
        )).data;
      }
      final results = await Future.wait([
        dio.get<dynamic>('users/me', options: options(workspaceId)),
        dio.get<dynamic>(
          'dashboard/mentions',
          queryParameters: {'workspaceId': workspaceId},
          options: options(workspaceId),
        ),
        dio.get<dynamic>(
          'messages/threads',
          queryParameters: {'workspaceId': workspaceId},
          options: options(workspaceId),
        ),
      ]);
      final current = results[0].data as Map;
      final userId = current['id']?.toString() ?? '';
      final entries = <Map<String, dynamic>>[
        for (final mention in items(results[1].data))
          {
            ...mention,
            'id': 'mention-${mention['id']}',
            'type': 'MENTION',
            'description': mention['text'],
            'metadata': {
              'taskId': mention['taskId'],
              'threadId': mention['threadId'],
            },
          },
        for (final thread in items(results[2].data))
          if (thread['threadId'] is String &&
              (thread['threadId'] as String).startsWith('dm:') &&
              (thread['threadId'] as String)
                  .split(':')
                  .skip(1)
                  .contains(userId) &&
              thread['user'] is Map &&
              thread['user']['id'] != null &&
              thread['user']['id'] != userId)
            {
              ...thread,
              'id': 'dm-${thread['threadId']}',
              'type': 'DM_MESSAGE',
              'description': thread['text'],
              'metadata': {'threadId': thread['threadId']},
            },
      ];
      entries.sort(
        (a, b) =>
            (DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                    DateTime(1970))
                .compareTo(
                  DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                      DateTime(1970),
                ),
      );
      return entries.take(6).toList();
    }
    if (kind == 'scrum-metadata') {
      final projects = items(
        (await dio.get<dynamic>(
          'projects',
          options: options(workspaceId),
        )).data,
      );
      final ids = <String>{};
      void visit(Map<String, dynamic> project) {
        if (project['id'] != null) ids.add(project['id'].toString());
        for (final child in project['children'] as List? ?? []) {
          if (child is Map) visit(Map<String, dynamic>.from(child));
        }
      }

      for (final project in projects) {
        if (project['workspaceId'] == null ||
            project['workspaceId'] == workspaceId) {
          visit(project);
        }
      }
      final groups = await Future.wait(
        ids.map((id) async {
          final results = await Future.wait([
            dio.get<dynamic>(
              'kanban-columns',
              queryParameters: {'projectId': id},
              options: options(workspaceId),
            ),
            dio.get<dynamic>(
              'epics',
              queryParameters: {'projectId': id},
              options: options(workspaceId),
            ),
          ]);
          return {
            'columns': items(results[0].data)
                .where((c) => c['archivedAt'] == null)
                .map((c) => {...c, 'projectId': id})
                .toList(),
            'epics': items(
              results[1].data,
            ).map((e) => {...e, 'projectId': id}).toList(),
          };
        }),
      );
      return {
        'columns': [for (final g in groups) ...g['columns']!],
        'epics': [for (final g in groups) ...g['epics']!],
      };
    }
    if (kind == 'recommendation-users') {
      final current = (await dio.get<dynamic>(
        'users/me',
        options: options(workspaceId),
      )).data;
      final user = current is Map
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      if (!['SUPER_ADMIN', 'ADMIN'].contains(user['role'])) {
        return {'currentUser': user, 'users': <dynamic>[]};
      }
      final users = (await dio.get<dynamic>(
        'users',
        options: options(workspaceId),
      )).data;
      return {'currentUser': user, 'users': items(users)};
    }
    final path = switch (kind) {
      'activity' => 'activity-log',
      'mentions' => 'dashboard/mentions',
      'reactions' => 'dashboard/reactions',
      'daily-motivation' => 'ai/daily-motivation',
      'team-projects' => 'projects',
      'team' => 'workspaces/${Uri.encodeComponent(workspaceId)}/members',
      _ => throw const DashboardException('Неизвестный виджет'),
    };
    return (await dio.get<dynamic>(
      path,
      queryParameters: {
        'workspaceId': workspaceId,
        if (kind == 'activity') 'limit': 20,
      },
      options: options(workspaceId),
    )).data;
  }
}

import 'package:dio/dio.dart';

import 'dashboard_repository.dart';
import 'entities/dashboard_layout.dart';

class ScopedDashboardRepository implements DashboardRepository {
  ScopedDashboardRepository(this.delegate, Iterable<String> workspaceIds)
    : workspaceIds = List.unmodifiable(workspaceIds);

  final DashboardRepository delegate;
  final List<String> workspaceIds;

  @override
  Future<DashboardLayout> load(
    String workspaceId, {
    CancelToken? cancelToken,
  }) => delegate.load(workspaceId, cancelToken: cancelToken);

  @override
  Future<DashboardLayout> save(String workspaceId, DashboardLayout layout) =>
      delegate.save(workspaceId, layout);

  @override
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  ) async => _unique(
    await Future.wait([
      for (final id in workspaceIds) delegate.tasks(id, projectIds),
    ]),
  );

  List<Map<String, dynamic>> _unique(Iterable<dynamic> groups) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final group in groups) {
      final rows = group is List
          ? group
          : group is Map
          ? group['data'] ??
                group['items'] ??
                group['members'] ??
                group['messages'] ??
                group['threads']
          : null;
      if (rows is! List) {
        throw const DashboardException('Некорректный ответ сервера');
      }
      for (final row in rows.whereType<Map>()) {
        final item = Map<String, dynamic>.from(row);
        final id = (item['id'] ?? item['userId'] ?? item['threadId'])
            ?.toString();
        if (id == null || seen.add(id)) result.add(item);
      }
    }
    return result;
  }

  @override
  Future<dynamic> widgetData(String workspaceId, String kind) async {
    if (kind == 'daily-motivation') {
      return delegate.widgetData(workspaceId, kind);
    }
    final groups = await Future.wait([
      for (final id in workspaceIds) delegate.widgetData(id, kind),
    ]);
    if (kind == 'scrum-metadata') {
      return {
        for (final key in ['columns', 'epics'])
          key: _unique([for (final group in groups) (group as Map)[key]]),
      };
    }
    if (kind == 'recommendation-users') {
      return {
        'currentUser': (groups.first as Map)['currentUser'],
        'users': _unique([for (final group in groups) (group as Map)['users']]),
      };
    }
    final rows = _unique(groups);
    if (kind == 'activity' || kind.startsWith('activity:')) {
      rows.sort(
        (a, b) =>
            (DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                    DateTime(1970))
                .compareTo(
                  DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                      DateTime(1970),
                ),
      );
      return rows.take(6).toList();
    }
    return rows;
  }
}

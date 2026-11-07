import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/domain/utils/task_column_label.dart';

void main() {
  test('real column names override standard statuses and custom codes', () {
    expect(
      taskColumnLabel(
        'col5',
        columns: const [
          KanbanColumnModel(id: 'c', name: 'Согласование', statusMap: 'COL5'),
        ],
      ),
      'Согласование',
    );
    expect(
      taskColumnLabel(
        'TODO',
        columns: const [
          KanbanColumnModel(
            id: 'c',
            name: 'Проверка документов',
            statusMap: 'TODO',
          ),
        ],
      ),
      'Проверка документов',
    );
    expect(taskColumnLabel('COL5', name: 'Согласование'), 'Согласование');
    expect(taskColumnLabel('COL5'), 'Колонка недоступна');
    expect(taskColumnLabel('COL5', name: 'COL5'), 'Колонка недоступна');
  });
  test('current column wins when an archived column uses the same code', () {
    expect(
      taskColumnLabel(
        'COL5',
        columns: const [
          KanbanColumnModel(
            id: 'old',
            name: 'Старое название',
            statusMap: 'COL5',
            archived: true,
          ),
          KanbanColumnModel(
            id: 'current',
            name: 'Согласование',
            statusMap: 'COL5',
          ),
        ],
      ),
      'Согласование',
    );
  });
  test(
    'dashboard resolves the same code separately for each project and refreshes renamed columns',
    () async {
      final adapter = _ColumnsAdapter();
      final repository = DashboardRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final tasks = await repository.tasks('w', ['p', 'q']);
      expect(tasks.map((t) => t['columnName']), ['Согласование', 'Приёмка']);
      expect(
        adapter.requests.every((r) => r.headers['X-Workspace-Id'] == 'w'),
        isTrue,
      );
      adapter.name = 'Утверждение';
      final refreshed = await repository.tasks('w', ['p', 'q']);
      expect(refreshed.first['columnName'], 'Утверждение');
      expect(refreshed.last['columnName'], 'Приёмка');
    },
  );
}

class _ColumnsAdapter implements HttpClientAdapter {
  String name = 'Согласование';
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final data = options.path == 'project-tasks'
        ? [
            {'id': 'a', 'projectId': 'p', 'status': 'COL5'},
            {'id': 'b', 'projectId': 'q', 'status': 'COL5'},
          ]
        : [
            {
              'id': 'c',
              'statusMap': 'COL5',
              'name': options.queryParameters['projectId'] == 'p'
                  ? name
                  : 'Приёмка',
            },
          ];
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_kpi_widget.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';

void main() {
  test(
    'dashboard uses web timing feed and paginates before workspace filtering',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              requests.add(r);
              final Object data;
              if (r.path == 'kanban-columns') {
                data = <Object>[];
              } else {
                expect(r.path, 'project-tasks/timing');
                expect(r.queryParameters['take'], 100);
                data = r.queryParameters['skip'] == 0
                    ? List.generate(
                        100,
                        (i) => {'id': 'other-$i', 'projectId': 'other'},
                      )
                    : [
                        {'id': 'included', 'projectId': 'p', 'status': 'DONE'},
                        {'id': 'archived', 'projectId': 'p', 'archived': true},
                      ];
              }
              h.resolve(
                Response(requestOptions: r, data: data, statusCode: 200),
              );
            },
          ),
        );
      addTearDown(dio.close);
      final tasks = await DashboardRepositoryImpl(dio).tasks('w', ['p']);
      expect(tasks.map((t) => t['id']), ['included']);
      expect(
        requests
            .where((r) => r.path == 'project-tasks/timing')
            .map((r) => r.queryParameters['skip']),
        [0, 100],
      );
    },
  );

  testWidgets(
    'all projects counts roots while including child tasks like web',
    (tester) async {
      ProjectModel project(
        String id, {
        List<ProjectModel> children = const [],
      }) => ProjectModel(
        id: id,
        code: id,
        name: id,
        workspaceId: 'w',
        start: null,
        end: null,
        children: children,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardKpiWidget(
                projects: [
                  for (var i = 0; i < 3; i++)
                    project('root$i', children: [project('child$i')]),
                ],
                tasks: const [
                  {'id': 't', 'projectId': 'child0', 'status': 'DONE'},
                ],
                onOpenTask: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('6'), findsNothing);
      final taskCaption = find.text('всего задач');
      expect(taskCaption, findsOneWidget);
      final total = find
          .ancestor(of: taskCaption, matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: total, matching: find.text('1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

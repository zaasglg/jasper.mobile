import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_dto.dart';
import 'package:jospar/features/tasks/data/models/task_label_dto.dart';
import 'package:jospar/features/tasks/data/models/task_label_catalog_dto.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/features/tasks/domain/entities/task_label_model.dart';
import 'package:jospar/features/tasks/domain/utils/task_label_utils.dart';
import 'package:jospar/features/tasks/domain/utils/task_column_label.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/models/task_creation_models.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';

void main() {
  test(
    'column DTO/entity conversions preserve every field and String status code',
    () {
      const entity = KanbanColumnModel(
        id: 'c',
        name: 'Doing',
        statusMap: 'COL1',
        projectId: 'p',
        color: '#abcdef',
        wip: 3,
        order: 2,
        archived: true,
      );
      final dto = KanbanColumnDto.fromEntity(entity);
      expect(dto.toEntity(), entity);
      expect(KanbanColumnDto.fromJson(dto.toJson()), dto);
      expect(dto.toJson(), {
        'id': 'c',
        'name': 'Doing',
        'statusMap': 'COL1',
        'projectId': 'p',
        'color': '#abcdef',
        'wip': 3,
        'order': 2,
        'archived': true,
      });
      expect(dto.copyWith(name: 'Other').statusMap, 'COL1');
      expect(entity.copyWith(name: 'Other').projectId, 'p');
      expect(
        taskColumnLabel('COL1', columns: [entity.copyWith(archived: false)]),
        'Doing',
      );
    },
  );
  test(
    'column aliases/defaults/null and malformed scalar coercion remain unchanged',
    () {
      expect(
        KanbanColumnDto.fromJson({}).toEntity(),
        const KanbanColumnModel(id: '', name: '', statusMap: ''),
      );
      final dto = KanbanColumnDto.fromJson({
        'id': 123,
        'name': {'x': 1},
        'status_map': 'IN_PROGRESS',
        'project_id': 42,
        'color': '  red  ',
        'wip': 3.9,
        'order': '5',
        'archived': 'TRUE',
      });
      expect(dto.id, '123');
      expect(dto.name, '{x: 1}');
      expect(dto.statusMap, 'IN_PROGRESS');
      expect(dto.projectId, '42');
      expect(dto.color, 'red');
      expect(dto.wip, 3);
      expect(dto.order, 5);
      expect(dto.archived, isTrue);
      final invalid = KanbanColumnDto.fromJson({
        'statusMap': {'a': 'b'},
        'color': ' ',
        'wip': 'bad',
        'order': null,
        'archived': 'yes',
      });
      expect(invalid.statusMap, '{a: b}');
      expect(invalid.color, isNull);
      expect(invalid.wip, isNull);
      expect(invalid.order, 0);
      expect(invalid.archived, isFalse);
      expect(KanbanColumnDto.fromJson({'archived': -1}).archived, isTrue);
    },
  );
  test('label unknown fields survive JSON/entity/copy round trip', () {
    final json = <String, dynamic>{
      'id': 'l',
      'text': 'Work',
      'color': 'red',
      'isPersonal': true,
      'ownerId': 'u',
      'metadata': {'keep': true},
    };
    final dto = TaskLabelDto.fromJson(json);
    final entity = dto.toEntity();
    expect(entity.unknownLabelFields, {
      'ownerId': 'u',
      'metadata': {'keep': true},
    });
    expect(TaskLabelDto.fromEntity(entity).toJson(), json);
    expect(TaskLabelDto.fromJson(dto.toJson()), dto);
    expect(TaskLabelDto.fromEntity(entity).toEntity(), entity);
    expect(
      TaskLabelDto.fromEntity(
        entity.copyWith(text: 'New'),
      ).toJson()['metadata'],
      {'keep': true},
    );
  });
  test('label defaults, aliases and strict personal markers are retained', () {
    expect(
      TaskLabelDto.fromJson({}).toEntity(),
      const TaskLabelModel(id: '', text: ''),
    );
    final dto = TaskLabelDto.fromJson({
      'id': 123,
      'name': {'nested': true},
      'color': null,
      'scope': 'personal',
    });
    expect(dto.id, '123');
    expect(dto.text, '{nested: true}');
    expect(dto.color, '#6366F1');
    expect(dto.isPersonal, isTrue);
    expect(
      TaskLabelDto.fromEntity(dto.toEntity()).toJson()['scope'],
      'personal',
    );
    expect(TaskLabelDto.fromJson({'isPersonal': 'true'}).isPersonal, isFalse);
    expect(TaskLabelDto.fromJson({'personal': true}).isPersonal, isTrue);
    expect(TaskLabelDto.fromJson({'text': '', 'name': 'Fallback'}).text, '');
  });
  test(
    'record catalog deduplicates normalized text per scope without losing metadata',
    () {
      final dto = TaskLabelCatalogDto.fromJson({
        'shared': [
          false,
          {'id': '1', 'text': ' Work ', 'extra': true},
          {'id': '2', 'text': 'work'},
          {'id': '3', 'text': ''},
        ],
        'personal': [
          {'id': 'p', 'text': 'WORK'},
        ],
      });
      final catalog = dto.toEntity();
      expect(catalog.shared.single.id, '1');
      expect(catalog.personal.single.id, 'p');
      expect(catalog.shared.single.unknownLabelFields['extra'], isTrue);
      final roundTrip = TaskLabelCatalogDto.fromEntity(catalog).toEntity();
      expect(roundTrip.shared, catalog.shared);
      expect(roundTrip.personal, catalog.personal);
      expect(TaskLabelCatalogDto.fromJson(dto.toJson()), dto);
      final empty = TaskLabelCatalogDto.fromJson({
        'shared': 'bad',
        'personal': null,
      }).toEntity();
      expect(empty.shared, isEmpty);
      expect(empty.personal, isEmpty);
      expect(taskLabelKey(' Work '), 'work');
      expect(
        uniqueTaskLabels([...catalog.shared, ...catalog.personal]).length,
        1,
      );
    },
  );
  test(
    'three deferred models convert only nested labels/columns without dropping sibling fields',
    () {
      final label = {
        'id': 'l',
        'text': 'Work',
        'color': 'red',
        'custom': {'keep': true},
      };
      final task = ProjectTaskModel.fromJson({
        'id': 't',
        'projectId': 'p',
        'title': 'Title',
        'status': 'COL1',
        'labels': [label],
      });
      expect(task.toJson()['labels'], [label]);
      expect(task.title, 'Title');
      expect(task.status, 'COL1');
      final detail = TaskDetailModel.fromJson({
        'description': 'Desc',
        'labels': [label],
        'unknownDetail': true,
      });
      expect(detail.toJson()['labels'], [label]);
      expect(detail.toJson()['unknownDetail'], isTrue);
      expect(detail.description, 'Desc');
      final options = TaskCreationOptions.fromJson({
        'columns': [
          {'id': 'c', 'name': 'Doing', 'statusMap': 'COL1'},
        ],
        'epics': [
          {'id': 'e', 'name': 'Epic'},
        ],
        'members': [
          {'id': 'u', 'name': 'User'},
        ],
        'tasks': [
          {'id': 't', 'title': 'Title'},
        ],
      });
      expect(options.columns.single, isA<KanbanColumnModel>());
      expect(options.toJson()['columns'], [
        KanbanColumnDto.fromEntity(options.columns.single).toJson(),
      ]);
      expect(options.toJson()['epics'], isNotEmpty);
      expect(options.toJson()['members'], isNotEmpty);
      expect(options.toJson()['tasks'], isNotEmpty);
    },
  );
  test(
    'PATCH sends complete label including unknown fields after entity edit; catalog is a record',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            final data = request.method == 'GET'
                ? {
                    'shared': [
                      {
                        'id': 'l',
                        'text': 'Work',
                        'color': 'red',
                        'custom': {'keep': true},
                      },
                    ],
                    'personal': [],
                  }
                : {
                    'id': 't',
                    'projectId': 'p',
                    'title': 'Title',
                    'detail': request.data['detail'],
                  };
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final repository = TaskDetailsRepositoryImpl(dio);
      final catalog = await repository.getLabelCatalog('t');
      final updated = catalog.shared.single.copyWith(text: 'Changed');
      final result = await repository.updateDetail(
        't',
        TaskDetailModel(labels: [updated]),
      );
      expect(requests.first.path, 'project-tasks/t/label-catalog');
      expect(requests.last.method, 'PATCH');
      expect(requests.last.path, 'project-tasks/t');
      expect(requests.last.data['detail']['labels'], [
        {
          'id': 'l',
          'text': 'Changed',
          'color': 'red',
          'custom': {'keep': true},
        },
      ]);
      expect(result.detail.labels.single.unknownLabelFields, {
        'custom': {'keep': true},
      });
    },
  );
}

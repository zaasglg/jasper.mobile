import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';

void main() {
  test('parses task detail, resources, comments, and checklist progress', () {
    final payload = TaskDetailsPayload.fromJson(<String, dynamic>{
      'id': 'task-1',
      'displayId': 'OPB-42',
      'projectId': 'project-1',
      'title': 'Новая задача',
      'status': 'TODO',
      'resources': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'resource-1',
          'name': 'Бюджет',
          'planValue': '1000',
          'factValue': '500',
          'order': 0,
        },
      ],
      'detail': <String, dynamic>{
        'description': 'Описание',
        'cover': <String, dynamic>{'type': 'color', 'color': '#fff'},
        'estimateMinutes': 90,
        'comments': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'comment-1',
            'author': 'Данияр',
            'text': 'Привет',
            'reactions': <Map<String, dynamic>>[
              <String, dynamic>{'emoji': '👍', 'count': 1},
            ],
          },
        ],
        'checklists': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'checklist-1',
            'name': 'Релиз',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'one', 'text': 'Готово', 'done': true},
              <String, dynamic>{'id': 'two', 'text': 'Тест', 'done': false},
            ],
          },
        ],
      },
    });

    expect(payload.task.displayId, 'OPB-42');
    expect(payload.resources.single.ratio, 0.5);
    expect(payload.detail.description, 'Описание');
    expect(payload.detail.estimateMinutes, 90);
    expect(payload.detail.comments.single.author, 'Данияр');
    expect(payload.detail.checklistCompleted, 1);
    expect(payload.detail.checklistTotal, 2);
    expect(payload.detail.checklistProgress, 0.5);

    final serialized = payload.detail.toJson();
    expect(serialized['cover'], isA<Map<Object?, Object?>>());
    final comments = serialized['comments']! as List<dynamic>;
    expect((comments.single as Map<String, dynamic>)['reactions'], isNotNull);
  });

  test('filters soft-deleted comments and supports legacy checklist', () {
    final detail = TaskDetailModel.fromJson(<String, dynamic>{
      'comments': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'active', 'author': 'A', 'text': 'Visible'},
        <String, dynamic>{
          'id': 'deleted',
          'author': 'B',
          'text': 'Hidden',
          'deletedAt': '2026-09-04T10:00:00Z',
        },
      ],
      'checklist': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'legacy', 'text': 'Old', 'done': false},
      ],
    });

    expect(detail.comments.map((comment) => comment.id), <String>['active']);
    expect(detail.checklists.single.name, 'Чек-лист');
    expect(detail.checklistTotal, 1);
  });
}

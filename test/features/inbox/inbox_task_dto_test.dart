import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_dto.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_detail_dto.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_label_dto.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_detail.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_label.dart';

void main() {
  test('DTO defaults and null/malformed values preserve parser behavior', () {
    expect(
      InboxTaskDto.fromJson({}).toEntity(),
      const InboxTaskModel(id: '', title: ''),
    );
    final task = InboxTaskDto.fromJson({
      'id': null,
      'title': ' ',
      'name': ' Name ',
      'completed': false,
      'archived': 'false',
      'order': 'bad',
      'createdAt': 'bad',
      'detail': false,
      'start': 123,
      'end': null,
      'priority': null,
    }).toEntity();
    expect(task.title, 'Name');
    expect(task.completed, isFalse);
    expect(task.archived, isFalse);
    expect(task.order, 0);
    expect(task.createdAt, isNull);
    expect(task.detail, const InboxTaskDetail());
    expect(task.start, '123');
    expect(task.end, isNull);
    expect(task.priority, 'MED');
  });
  test('aliases, scalar coercion, dates and detail description fallback', () {
    final dto = InboxTaskDto.fromJson({
      'task_id': 123,
      'display_id': 'IN-1',
      'subject': ' Subject ',
      'isCompleted': 'yes',
      'isArchived': 1,
      'sort': 3.9,
      'created_at': '2026-01-02T03:04:05+06:00',
      'detail': {
        'description': ' Description ',
        'labels': [
          {'id': 42, 'text': 'Work', 'color': '#123456'},
        ],
        'files': [
          {'id': 'f'},
        ],
      },
    });
    final task = dto.toEntity();
    expect(task.id, '123');
    expect(task.displayId, 'IN-1');
    expect(task.title, 'Subject');
    expect(task.description, 'Description');
    expect(task.detail.description, ' Description ');
    expect(task.completed, isTrue);
    expect(task.archived, isTrue);
    expect(task.order, 3);
    expect(task.createdAt, DateTime.parse('2026-01-01T21:04:05Z'));
    expect(dto.toJson()['createdAt'], '2026-01-01T21:04:05.000Z');
    expect(task.detail.labels!.single.id, '42');
    expect(task.detail.unknownDetailFields, {
      'files': [
        {'id': 'f'},
      ],
    });
    expect(InboxTaskDto.fromEntity(task).toEntity(), task);
  });
  for (final json in <Map<String, dynamic>>[
    {'status': 'done'},
    {
      'detail': {'completed': 'yes'},
    },
    {'completedAt': ''},
    {'completed_at': 123},
    {'isCompleted': -1},
  ]) {
    test('completion source remains supported: $json', () {
      expect(InboxTaskDto.fromJson(json).toEntity().completed, isTrue);
    });
  }
  test('title and description fallback precedence remains unchanged', () {
    expect(
      InboxTaskDto.fromJson({
        'title': '',
        'name': ' ',
        'subject': ' Subject ',
        'content': 'Other',
      }).title,
      'Subject',
    );
    expect(
      InboxTaskDto.fromJson({
        'description': 'Top',
        'detail': {'description': 'Nested'},
      }).description,
      'Top',
    );
    expect(InboxTaskDto.fromJson({'detail': ' Legacy '}).description, 'Legacy');
    expect(InboxTaskDto.fromJson({'body': 123}).description, '123');
  });
  test('all entity fields survive conversion and copyWith', () {
    final entity = InboxTaskModel(
      id: 'id',
      title: 'Title',
      displayId: 'IN',
      description: 'Desc',
      completed: true,
      archived: true,
      order: 4,
      createdAt: DateTime.utc(2026),
      isLocalOnly: true,
      start: '2026-01-01',
      end: '2026-01-02',
      priority: 'HIGH',
      detail: const InboxTaskDetail(
        description: 'Desc',
        completed: true,
        labels: [InboxTaskLabel(id: 'l', text: 'Work', color: 'red')],
        unknownDetailFields: {
          'files': [1],
        },
      ),
    );
    final dto = InboxTaskDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(dto.copyWith(title: 'New').detail, dto.detail);
    expect(entity.copyWith(title: 'New').detail, entity.detail);
    // Existing local-only flag is not part of the API JSON contract.
    expect(dto.toJson().containsKey('isLocalOnly'), isFalse);
  });
  test(
    'unknown detail fields survive edit, empty-label deletion and DTO round trips',
    () {
      final dto = InboxTaskDetailDto.fromJson({
        'description': 'Old',
        'completed': true,
        'labels': [
          {'id': 'l', 'text': 'Work'},
        ],
        'files': [
          {'id': 'f'},
        ],
        'custom': {'keep': true},
      });
      final edited = dto.toEntity().copyWith(description: 'New', labels: []);
      expect(InboxTaskDetailDto.fromEntity(edited).toJson(), {
        'description': 'New',
        'completed': true,
        'labels': [],
        'files': [
          {'id': 'f'},
        ],
        'custom': {'keep': true},
      });
      expect(InboxTaskDetailDto.fromEntity(edited).toEntity(), edited);
      expect(InboxTaskDetailDto.fromJson(dto.toJson()), dto);
    },
  );
  test(
    'detail and label DTOs preserve raw JSON while exposing typed fields',
    () {
      final detail = InboxTaskDetailDto.fromJson({
        'description': 123,
        'labels': [
          false,
          {'text': 123},
        ],
        'completed': 0,
      });
      expect(detail.toEntity().description, '123');
      expect(detail.toEntity().labels!.single.text, '123');
      expect(detail.toEntity().completed, isFalse);
      expect(
        InboxTaskDetailDto.fromJson({'labels': 'bad'}).toEntity().labels,
        isNull,
      );
      expect(
        InboxTaskDetailDto.fromJson({
          'description': null,
        }).toEntity().description,
        isNull,
      );
      const label = InboxTaskLabel(id: '1', text: 'Label', color: 'red');
      expect(InboxTaskLabelDto.fromEntity(label).toEntity(), label);
      expect(
        InboxTaskLabelDto.fromJson(
          InboxTaskLabelDto.fromEntity(label).toJson(),
        ).toEntity(),
        label,
      );
      expect(label.copyWith(text: 'Other').color, 'red');
    },
  );
}

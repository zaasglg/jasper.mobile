import 'package:jospar/features/projects/data/models/create_project_request_dto.dart';
import 'package:jospar/features/projects/data/models/project_dto.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/projects/data/models/project_task_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'personal labels are included alongside shared labels and preserved after moving',
    () {
      final task = ProjectTaskDto.fromJson({
        'detail': {
          'labels': [
            {'id': 'shared', 'text': 'Общая', 'color': '#6366F1'},
          ],
          'personalLabels': [
            {'id': 'private', 'text': 'Личная', 'color': '#d09835'},
          ],
        },
      }).toEntity();
      expect(task.labels.length, 2);
      expect(task.labels.first.isPersonal, false);
      expect(task.labels.last.isPersonal, true);
      final restored = ProjectTaskDto.fromJson(
        ProjectTaskDto.fromEntity(task.copyWith(status: 'DONE')).toJson(),
      ).toEntity();
      expect(restored.labels.last.text, 'Личная');
      expect(restored.labels.last.isPersonal, true);
      expect(restored.labels.last.color, '#d09835');
    },
  );

  test('checklist count includes items and sections across multiple lists', () {
    final task = ProjectTaskDto.fromJson({
      'detail': {
        'checklists': [
          {
            'items': [
              {'id': '1', 'done': true},
              {'id': '2', 'done': false},
            ],
            'sections': [
              {
                'items': [
                  {'id': '3', 'done': true},
                ],
              },
            ],
          },
          {
            'items': [
              {'id': '4', 'done': false},
            ],
          },
        ],
      },
    }).toEntity();
    expect(task.checklistTotal, 4);
    expect(task.checklistCompleted, 2);
    final restored = ProjectTaskDto.fromJson(
      ProjectTaskDto.fromEntity(task.copyWith(status: 'DONE')).toJson(),
    ).toEntity();
    expect(restored.checklistTotal, 4);
    expect(restored.checklistCompleted, 2);
    final legacy = ProjectTaskDto.fromJson({
      'detail': '{"checklist":[{"done":true},{"done":false}]}',
    }).toEntity();
    expect(legacy.checklistTotal, 2);
    expect(legacy.checklistCompleted, 1);
  });

  test(
    'discussion count reads active detail comments and legacy summaries',
    () {
      final task = ProjectTaskDto.fromJson({
        'detail': {
          'comments': [
            {'id': '1', 'text': 'Обсуждение'},
            {'id': '2', 'deletedAt': '2026-10-05T10:00:00Z'},
            {'id': '3', 'deleted_at': '2026-10-05T10:00:00Z'},
          ],
        },
      }).toEntity();
      expect(task.commentCount, 1);
      expect(
        ProjectTaskDto.fromJson(
          ProjectTaskDto.fromEntity(task.copyWith(status: 'DONE')).toJson(),
        ).toEntity().commentCount,
        1,
      );
      expect(
        ProjectTaskDto.fromJson({'comments': 4}).toEntity().commentCount,
        4,
      );
      expect(
        ProjectTaskDto.fromJson({'commentsCount': '3'}).toEntity().commentCount,
        3,
      );
      expect(
        ProjectTaskDto.fromJson({
          'detail': '{"comments":[{"id":"1"}]}',
        }).toEntity().commentCount,
        1,
      );
      expect(
        ProjectTaskDto.fromJson({
          'detail': 'Обычный текст',
        }).toEntity().commentCount,
        0,
      );
    },
  );

  test(
    'attachment counts read detail files and survive moves and serialization',
    () {
      for (final detail in [
        {
          'files': [
            {'id': '1'},
            {'id': '2'},
            null,
          ],
        },
        '{"files":[{"id":"1"},{"id":"2"},null]}',
      ]) {
        final task = ProjectTaskDto.fromJson({'detail': detail}).toEntity();
        expect(task.fileCount, 2);
        expect(
          ProjectTaskDto.fromJson(
            ProjectTaskDto.fromEntity(task.copyWith(status: 'DONE')).toJson(),
          ).toEntity().fileCount,
          2,
        );
      }
      expect(
        ProjectTaskDto.fromJson({'filesCount': '5'}).toEntity().fileCount,
        5,
      );
      expect(
        ProjectTaskDto.fromJson({'detail': 'text'}).toEntity().fileCount,
        0,
      );
      expect(
        ProjectTaskDto.fromJson({
          'detail': {'files': []},
        }).toEntity().fileCount,
        0,
      );
    },
  );

  test(
    'board task reads nested labels and colored epics without losing them on copy or JSON round trip',
    () {
      final task = ProjectTaskDto.fromJson({
        'id': 'task',
        'projectId': 'p',
        'status': 'TODO',
        'detail': {
          'labels': [
            {'id': 'label', 'text': 'Личная метка', 'color': '#e19b31'},
            {'id': 'empty', 'text': '  '},
          ],
        },
        'epics': [
          {
            'epicId': 'e1',
            'epic': {'name': 'Архитектура', 'color': '#128867'},
          },
          {'id': 'e2', 'name': 'Релиз', 'color': '#6366F1'},
        ],
      }).toEntity();
      expect(task.labels.single.text, 'Личная метка');
      expect(task.labels.single.color, '#e19b31');
      expect(task.epics.first.color, '#128867');
      expect(task.epics.last.id, 'e2');
      final moved = task.copyWith(status: 'DONE', order: 2);
      final restored = ProjectTaskDto.fromJson(
        ProjectTaskDto.fromEntity(moved).toJson(),
      ).toEntity();
      expect(restored.labels, task.labels);
      expect(restored.epics, task.epics);
    },
  );

  test('labels support JSON detail and ignore malformed legacy detail', () {
    final task = ProjectTaskDto.fromJson({
      'detail': '{"labels":[{"id":"l","text":"Метка"}]}',
    }).toEntity();
    expect(task.labels.single.text, 'Метка');
    expect(
      ProjectTaskDto.fromJson({'detail': 'Обычный текст'}).toEntity().labels,
      isEmpty,
    );
    expect(
      ProjectTaskDto.fromJson({
        'detail': {'labels': null},
      }).toEntity().labels,
      isEmpty,
    );
  });

  test('ProjectModel parses flexible API values', () {
    final project = ProjectDto.fromJson(<String, dynamic>{
      'id': 'p1',
      'code': 'APP',
      'name': 'Приложение',
      'workspace_id': 'w1',
      'start': '2026-08-21T00:00:00.000Z',
      'end': '2026-09-21T00:00:00.000Z',
      'progress': '45',
      'is_pinned': 1,
    }).toEntity();

    expect(project.workspaceId, 'w1');
    expect(project.progress, 45);
    expect(project.isPinned, isTrue);
    expect(project.start, DateTime.utc(2026, 8, 21));
  });

  test('ProjectModel parses nested child projects', () {
    final project = ProjectDto.fromJson(<String, dynamic>{
      'id': 'root',
      'name': 'Root',
      'workspaceId': 'workspace',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'child',
          'name': 'Child',
          'workspaceId': 'workspace',
        },
      ],
    }).toEntity();

    expect(project.children.single.id, 'child');
    expect(ProjectDto.fromEntity(project).toJson()['children'], isNotEmpty);
  });

  test(
    'ProjectTaskModel matches web progress completion independently of status',
    () {
      const byStatus = ProjectTaskModel(
        id: '1',
        projectId: 'project',
        status: 'done',
      );
      final byProgress = ProjectTaskDto.fromJson(<String, dynamic>{
        'id': '2',
        'project_id': 'project',
        'status': 'IN_PROGRESS',
        'progress': '100',
      }).toEntity();

      expect(byStatus.isDone, isFalse);
      expect(byProgress.isDone, isTrue);
      expect(byProgress.projectId, 'project');
    },
  );

  test('ProjectTaskModel treats Unix epoch deadline as absent', () {
    final fromIso = ProjectTaskDto.fromJson(<String, dynamic>{
      'id': '1',
      'projectId': 'project',
      'status': 'TODO',
      'end': '1970-01-01T00:00:00.000Z',
    }).toEntity();
    final fromTimestamp = ProjectTaskDto.fromJson(<String, dynamic>{
      'id': '2',
      'projectId': 'project',
      'status': 'TODO',
      'end': 0,
    }).toEntity();

    expect(fromIso.end, isNull);
    expect(fromTimestamp.end, isNull);
  });

  test('ProjectTaskModel parses assignee profile data', () {
    final task = ProjectTaskDto.fromJson(<String, dynamic>{
      'id': '1',
      'projectId': 'project',
      'status': 'TODO',
      'assignees': <Map<String, dynamic>>[
        <String, dynamic>{
          'user': <String, dynamic>{
            'id': 'user-1',
            'firstName': 'Анна',
            'lastName': 'Смирнова',
            'avatarUrl': 'https://example.com/avatar.png',
          },
        },
      ],
    }).toEntity();

    expect(task.assignees.single.userId, 'user-1');
    expect(task.assignees.single.name, 'Анна Смирнова');
    expect(task.assignees.single.avatarUrl, 'https://example.com/avatar.png');
  });

  test(
    'CreateProjectRequest sends UTC dates and omits empty optional fields',
    () {
      final request = CreateProjectRequest(
        code: ' MOB ',
        name: ' Mobile ',
        description: '   ',
        workspaceId: 'w1',
        start: DateTime(2026, 8, 21),
        end: DateTime(2026, 9, 21),
        progress: 10,
        parentId: '',
        isPinned: true,
      );

      final json = CreateProjectRequestDto.fromEntity(request).toJson();
      expect(json['code'], 'MOB');
      expect(json['name'], 'Mobile');
      expect(json['start'], endsWith('Z'));
      expect(json['end'], endsWith('Z'));
      expect(json, isNot(contains('description')));
      expect(json, isNot(contains('parentId')));
    },
  );
}

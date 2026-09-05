import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';

void main() {
  test('ProjectModel parses flexible API values', () {
    final project = ProjectModel.fromJson(<String, dynamic>{
      'id': 'p1',
      'code': 'APP',
      'name': 'Приложение',
      'workspace_id': 'w1',
      'start': '2026-08-21T00:00:00.000Z',
      'end': '2026-09-21T00:00:00.000Z',
      'progress': '45',
      'is_pinned': 1,
    });

    expect(project.workspaceId, 'w1');
    expect(project.progress, 45);
    expect(project.isPinned, isTrue);
    expect(project.start, DateTime.utc(2026, 8, 21));
  });

  test('ProjectModel parses nested child projects', () {
    final project = ProjectModel.fromJson(<String, dynamic>{
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
    });

    expect(project.children.single.id, 'child');
    expect(project.toJson()['children'], isNotEmpty);
  });

  test('ProjectTaskModel recognizes both completion rules', () {
    const byStatus = ProjectTaskModel(
      id: '1',
      projectId: 'project',
      status: 'done',
    );
    final byProgress = ProjectTaskModel.fromJson(<String, dynamic>{
      'id': '2',
      'project_id': 'project',
      'status': 'IN_PROGRESS',
      'progress': '100',
    });

    expect(byStatus.isDone, isTrue);
    expect(byProgress.isDone, isTrue);
    expect(byProgress.projectId, 'project');
  });

  test('ProjectTaskModel treats Unix epoch deadline as absent', () {
    final fromIso = ProjectTaskModel.fromJson(<String, dynamic>{
      'id': '1',
      'projectId': 'project',
      'status': 'TODO',
      'end': '1970-01-01T00:00:00.000Z',
    });
    final fromTimestamp = ProjectTaskModel.fromJson(<String, dynamic>{
      'id': '2',
      'projectId': 'project',
      'status': 'TODO',
      'end': 0,
    });

    expect(fromIso.end, isNull);
    expect(fromTimestamp.end, isNull);
  });

  test('ProjectTaskModel parses assignee profile data', () {
    final task = ProjectTaskModel.fromJson(<String, dynamic>{
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
    });

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

      final json = request.toJson();
      expect(json['code'], 'MOB');
      expect(json['name'], 'Mobile');
      expect(json['start'], endsWith('Z'));
      expect(json['end'], endsWith('Z'));
      expect(json, isNot(contains('description')));
      expect(json, isNot(contains('parentId')));
    },
  );
}

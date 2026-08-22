import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';

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

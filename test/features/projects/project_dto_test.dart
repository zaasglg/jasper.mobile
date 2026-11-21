import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/projects/data/models/project_dto.dart';
import 'package:jospar/features/projects/data/models/create_project_request_dto.dart';
import 'package:jospar/features/projects/data/models/project_task_dto.dart';
import 'package:jospar/features/projects/data/models/project_task_cover_dto.dart';
import 'package:jospar/features/projects/data/models/project_task_detail_snapshot_dto.dart';
import 'package:jospar/features/projects/data/models/task_assignee_dto.dart';
import 'package:jospar/features/projects/data/models/task_epic_dto.dart';
import 'package:jospar/features/projects/data/repositories/project_repository_impl.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:jospar/features/projects/domain/entities/project_task_cover.dart';
import 'package:jospar/features/projects/domain/entities/project_task_detail_snapshot.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/tasks/domain/entities/task_label_model.dart';

void main() {
  test('project DTO preserves recursive children through entity and JSON', () {
    final dto = ProjectDto.fromJson({
      'id': 12,
      'workspace_id': 'w',
      'progress': '120',
      'is_pinned': 1,
      'children': [
        null,
        {
          'id': 'child',
          'children': [
            {'id': 'leaf'},
          ],
        },
      ],
    });
    expect(dto.toEntity().id, '12');
    expect(dto.progress, 100);
    expect(dto.isPinned, isTrue);
    expect(dto.children.single.children.single.id, 'leaf');
    expect(ProjectDto.fromEntity(dto.toEntity()), dto);
    expect(ProjectDto.fromJson(dto.toJson()), dto);
  });

  test(
    'project DTO retains defaults and rejects malformed dates without throwing',
    () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'id': null, 'children': null},
        {'start': 'bad', 'end': {}, 'children': 2, 'progress': 'bad'},
      ]) {
        final dto = ProjectDto.fromJson(json);
        expect(dto.id, '');
        expect(dto.start, isNull);
        expect(dto.end, isNull);
        expect(dto.children, isEmpty);
        expect(dto.progress, 0);
      }
      expect(
        ProjectDto.fromJson({
          'id': {'nested': 1},
        }).id,
        '{nested: 1}',
      );
    },
  );

  test('create request DTO preserves mapping and exact body normalization', () {
    final entity = CreateProjectRequest(
      code: ' APP ',
      name: ' Name ',
      workspaceId: ' w ',
      description: '  ',
      parentId: ' parent ',
      start: DateTime.utc(2026, 10, 1),
      progress: 12,
      isPinned: true,
    );
    final dto = CreateProjectRequestDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(dto.toJson(), {
      'code': 'APP',
      'name': 'Name',
      'workspaceId': ' w ',
      'start': '2026-10-01T00:00:00.000Z',
      'progress': 12.0,
      'isPinned': true,
      'parentId': 'parent',
    });
    expect(
      CreateProjectRequestDto.fromJson(dto.toJson()).toJson(),
      dto.toJson(),
    );
  });

  test(
    'create request DTO keeps missing/null defaults and strict numeric/bool casts',
    () {
      expect(CreateProjectRequestDto.fromJson({}).toJson(), {
        'code': '',
        'name': '',
        'workspaceId': '',
        'progress': 0.0,
        'isPinned': false,
      });
      expect(
        CreateProjectRequestDto.fromJson({
          'progress': null,
          'isPinned': null,
          'start': 'invalid',
        }).start,
        isNull,
      );
      expect(
        () => CreateProjectRequestDto.fromJson({'progress': '10'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => CreateProjectRequestDto.fromJson({'isPinned': 1}),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test(
    'assignee and epic DTOs preserve aliases, nested data, defaults and mappings',
    () {
      final assignee = TaskAssigneeDto.fromJson({
        'user': {
          'id': 7,
          'firstName': ' A ',
          'lastName': ' B ',
          'avatar_url': '/a.png',
        },
      });
      expect(assignee.userId, '7');
      expect(assignee.name, 'A B');
      expect(assignee.avatarUrl, '/a.png');
      expect(TaskAssigneeDto.fromEntity(assignee.toEntity()), assignee);
      expect(TaskAssigneeDto.fromJson(assignee.toJson()), assignee);
      final epic = TaskEpicDto.fromJson({
        'epic_id': 4,
        'epic': {'name': 'Epic', 'color': '#abc'},
      });
      expect(epic.id, '4');
      expect(TaskEpicDto.fromEntity(epic.toEntity()), epic);
      expect(TaskEpicDto.fromJson(epic.toJson()), epic);
      for (final json in <Map<String, dynamic>>[
        {},
        {'user': null, 'epic': null},
        {'user': 1, 'epic': [], 'avatar': null},
      ]) {
        expect(TaskAssigneeDto.fromJson(json).userId, '');
        expect(TaskEpicDto.fromJson(json).id, '');
        expect(TaskEpicDto.fromJson(json).color, '#6d5fe0');
      }
    },
  );

  test(
    'task DTO retains aliases, timer/date/default parsing and complete entity mapping',
    () {
      final dto = ProjectTaskDto.fromJson({
        'id': 1,
        'display_id': 'A-1',
        'project_id': 'p',
        'status': 'DONE',
        'progress': '101',
        'deps': [2],
        'start': 1790812800,
        'end': 0,
        'est': '2.5',
        'order': '3',
        'timerElapsedMs': '4',
        'timerStartedAt': '2026-10-01T00:00:00Z',
        'archived': 1,
        'isTimingEnabled': false,
        'assignees': [
          null,
          {'user_id': 'u'},
        ],
        'epics': [
          {'id': 'e'},
        ],
        'labels': [
          {
            'id': 'l',
            'text': 'Label',
            'custom': {'x': 1},
          },
        ],
        'detail': {'description': 'unchanged'},
      });
      expect(dto.toEntity().isDone, isTrue);
      expect(dto.progress, 100);
      expect(dto.end, isNull);
      expect(dto.deps, ['2']);
      expect(dto.estimate, 2.5);
      expect(dto.timerElapsedMs, 4);
      expect(dto.archived, isTrue);
      expect(ProjectTaskDto.fromEntity(dto.toEntity()).toJson(), dto.toJson());
      expect(ProjectTaskDto.fromJson(dto.toJson()), dto);
      for (final json in <Map<String, dynamic>>[
        {},
        {'detail': null},
        {'assignees': 1, 'epics': 'bad', 'labels': {}, 'start': 'bad'},
      ]) {
        final value = ProjectTaskDto.fromJson(json).toEntity();
        expect(value.id, '');
        expect(value.labels, isEmpty);
        expect(value.assignees, isEmpty);
        expect(value.epics, isEmpty);
        expect(value.start, isNull);
      }
    },
  );

  test(
    'missing counters are computed from collections; explicit counters take precedence',
    () {
      final json = <String, dynamic>{
        'resources': [
          {'id': 'r'},
        ],
        'detail': {
          'files': [
            {'id': 'f'},
            null,
          ],
          'comments': [
            {'id': 'c'},
            {'id': 'deleted', 'deletedAt': 'today'},
          ],
          'checklists': [
            {
              'items': [
                {'done': true},
                {'done': false},
              ],
              'sections': [
                {
                  'items': [
                    {'completed': true},
                  ],
                },
              ],
            },
          ],
        },
      };
      final entity = ProjectTaskDto.fromJson(json).toEntity();
      expect(entity.fileCount, 1);
      expect(entity.commentCount, 1);
      expect(entity.resourceCount, 1);
      expect(entity.checklistTotal, 3);
      expect(entity.checklistCompleted, 2);
      final explicit = ProjectTaskDto.fromJson({
        ...json,
        'filesCount': 8,
        'commentsCount': 9,
        'resourcesCount': 10,
        'checklistTotal': 11,
        'checklistCompleted': 4,
      }).toEntity();
      expect(explicit.fileCount, 8);
      expect(explicit.commentCount, 9);
      expect(explicit.resourceCount, 10);
      expect(explicit.checklistTotal, 11);
      expect(explicit.checklistCompleted, 4);
      expect(ProjectTaskDto.fromEntity(entity).toEntity(), entity);
    },
  );

  test(
    'typed detail preserves unknown collections and userId dictionaries on round trip',
    () {
      final dto = ProjectTaskDetailSnapshotDto.fromJson({
        'labels': [
          {'id': 's', 'text': 'Shared'},
        ],
        'personalLabels': {
          'u': [
            {'id': 'p', 'text': 'Private'},
          ],
          'empty': [],
        },
        'files': [
          {'id': 'f', 'extra': true},
        ],
        'comments': [],
        'checklists': [
          {'items': []},
        ],
        'description': 'text',
        'resources': [1],
      });
      final entity = dto.toEntity();
      expect(entity.labels!.single.id, 's');
      expect(entity.personalLabelsByUser.keys, ['u', 'empty']);
      expect(
        entity.unknownDetailFields.keys,
        containsAll([
          'files',
          'comments',
          'checklists',
          'description',
          'resources',
        ]),
      );
      expect(entity.unknownDetailFields, isNot(contains('labels')));
      final restored = ProjectTaskDetailSnapshotDto.fromEntity(
        entity,
      ).toEntity();
      expect(restored, entity);
      expect(
        ProjectTaskDetailSnapshotDto.fromEntity(entity).toJson()['files'],
        dto.fields['files'],
      );
    },
  );

  test(
    'typed fields override unknown fields and never serialize displayUrl',
    () {
      const snapshot = ProjectTaskDetailSnapshot(
        cover: ProjectTaskCover(
          type: 'image',
          url: '/source.png',
          displayUrl: 'data:image/png;base64,AQID',
        ),
        labels: [TaskLabelModel(id: 'typed', text: 'Typed')],
        unknownDetailFields: {
          'cover': {'url': 'wrong'},
          'labels': ['wrong'],
          'files': [1],
        },
      );
      final json = ProjectTaskDetailSnapshotDto.fromEntity(snapshot).toJson();
      expect(json['cover'], {'type': 'image', 'url': '/source.png'});
      expect((json['labels'] as List).single['id'], 'typed');
      expect(json['files'], [1]);
      expect(jsonEncode(json), isNot(contains('displayUrl')));
    },
  );

  test(
    'legacy text, list personalLabels, null and malformed detail remain supported',
    () {
      for (final text in ['plain description', '{bad', '[1,2]', 'null']) {
        final entity = ProjectTaskDto.fromJson({'detail': text}).toEntity();
        expect(entity.detail!.legacyText, text);
        expect(ProjectTaskDto.fromEntity(entity).toJson()['detail'], text);
      }
      final legacy = ProjectTaskDto.fromJson({
        'detail': {
          'personalLabels': [
            {'id': 'p', 'text': 'Private'},
          ],
        },
      }).toEntity();
      expect(legacy.detail!.legacyPersonalLabels!.single.id, 'p');
      expect(legacy.labels.single.isPersonal, isTrue);
      final malformed = ProjectTaskDetailSnapshotDto.fromJson({
        'cover': null,
        'labels': 7,
        'personalLabels': {'bad': 5, 'empty': []},
      });
      expect(
        ProjectTaskDetailSnapshotDto.fromEntity(malformed.toEntity()).toJson(),
        malformed.toJson(),
      );
    },
  );

  test(
    'labelsForUser distinguishes absent user from an explicitly empty list',
    () {
      final task = ProjectTaskDto.fromJson({
        'labels': [
          {'id': 's', 'text': 'Shared'},
          {'id': 'old', 'text': 'Old', 'isPersonal': true},
        ],
        'detail': {
          'personalLabels': {
            'u': [
              {'id': 'new', 'text': 'New'},
            ],
            'empty': [],
          },
        },
      }).toEntity();
      expect(task.labelsForUser(null), task.labels);
      expect(task.labelsForUser('absent'), task.labels);
      expect(task.labelsForUser('empty').map((e) => e.id), ['s']);
      expect(task.labelsForUser('u').map((e) => e.id), ['s', 'new']);
      expect(task.labelsForUser('u').last.isPersonal, isTrue);
      expect(
        task.detail!.personalLabelsByUser['u']!.single.isPersonal,
        isFalse,
      );
    },
  );

  for (final source in [
    'https://cdn/x.png',
    '/cover.png',
    'data:image/png;base64,AQID',
  ]) {
    test(
      'cover display URL is resolved once and source preserved: $source',
      () {
        final dto = ProjectTaskCoverDto.fromJson({
          'type': 'image',
          'imageUrl': source,
        });
        final entity = dto.toEntity();
        final expected = source.startsWith('/')
            ? ApiConstants.origin.resolve(source).toString()
            : source;
        expect(entity.displayUrl, expected);
        expect(entity.imageUrl, source);
        expect(resolveUserAvatarUrl(entity.displayUrl), expected);
        expect(ProjectTaskCoverDto.fromEntity(entity).toJson(), {
          'type': 'image',
          'imageUrl': source,
        });
        expect(ProjectTaskCoverDto.fromEntity(entity), dto);
      },
    );
  }

  test(
    'cover resolves task and comment attachments without overwriting source URLs',
    () {
      for (final fileId in ['f', 'cfile__c__0']) {
        final task = ProjectTaskDto.fromJson({
          'detail': {
            'cover': {
              'type': 'image',
              'fileId': fileId,
              'url': '/original.png',
            },
            'files': [
              {'id': 'f', 'dataUrl': 'data:image/png;base64,AQID'},
            ],
            'comments': [
              {
                'id': 'c',
                'files': [
                  {'dataUrl': 'data:image/png;base64,AQID'},
                ],
              },
            ],
          },
        }).toEntity();
        expect(task.cover!.displayUrl, 'data:image/png;base64,AQID');
        expect(task.cover!.url, '/original.png');
        final detail = jsonDecode(ProjectTaskDto.fromEntity(task).detail!);
        expect(detail['cover'], {
          'type': 'image',
          'fileId': fileId,
          'url': '/original.png',
        });
        expect(ProjectTaskDto.fromEntity(task).toEntity(), task);
      }
      const direct = ProjectTaskModel(
        id: 't',
        projectId: 'p',
        status: 'TODO',
        detail: ProjectTaskDetailSnapshot(
          cover: ProjectTaskCover(url: '/raw.png'),
        ),
      );
      expect(direct.cover!.displayUrl, isNull);
      expect(
        ProjectTaskCoverDto.fromJson({'url': 'javascript:bad'}).displayUrl,
        isNull,
      );
    },
  );

  test(
    'project repository retains GET query and POST request/response formats',
    () async {
      final adapter = _ProjectAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = ProjectRepositoryImpl(dio);
      final projects = await repository.getProjects();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(projects.single.children.single.id, 'child');
      final created = await repository.createProject(
        const CreateProjectRequest(
          code: ' APP ',
          name: ' Name ',
          workspaceId: 'w',
          description: ' ',
        ),
      );
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, 'projects');
      expect(adapter.requests.last.data, {
        'code': 'APP',
        'name': 'Name',
        'workspaceId': 'w',
        'progress': 0.0,
        'isPinned': false,
      });
      expect(created.id, 'created');
      expect(created.workspaceId, 'w');
    },
  );
}

class _ProjectAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(
        options.method == 'GET'
            ? [
                {
                  'id': 'p',
                  'workspaceId': 'w',
                  'children': [
                    {'id': 'child'},
                  ],
                },
              ]
            : {
                'data': {'id': 'created', 'name': 'Name'},
              },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

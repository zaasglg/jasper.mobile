import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/assistant/data/models/assistant_message_dto.dart';
import 'package:jospar/features/assistant/data/models/assistant_draft_dto.dart';
import 'package:jospar/features/assistant/data/models/assistant_tool_dto.dart';
import 'package:jospar/features/assistant/data/services/assistant_actions.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_message_model.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_tool.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_tool_result.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_draft.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_draft_previous.dart';

void main() {
  test(
    'message DTO defaults, coercion and list filtering preserve parser contract',
    () {
      expect(
        AssistantMessageDto.fromJson({}).toEntity(),
        const AssistantMessageModel(role: 'assistant', content: ''),
      );
      final dto = AssistantMessageDto.fromJson({
        'role': 123,
        'content': {'a': 1},
        'images': ['image', 42],
        'toolCalls': [
          null,
          {'name': 'unknown', 'extra': true},
        ],
        'draft': 'invalid',
        'actionStates': {42: null},
      });
      expect(dto.role, '123');
      expect(dto.content, '{a: 1}');
      expect(dto.images, ['image']);
      expect(dto.toEntity().tools.single.name, 'unknown');
      expect(dto.toEntity().draft, isNull);
      expect(dto.actionStates, {'42': 'null'});
      expect(AssistantMessageDto.fromJson(dto.toJson()), dto);
    },
  );
  for (final key in ['images', 'toolCalls', 'actionStates']) {
    test('rejects incompatible $key JSON type', () {
      expect(
        () => AssistantMessageDto.fromJson({key: 123}),
        throwsA(isA<TypeError>()),
      );
    });
  }
  test(
    'message serializes empty optional values exactly and converts both ways',
    () {
      const entity = AssistantMessageModel(role: 'user', content: 'Text');
      final dto = AssistantMessageDto.fromEntity(entity);
      expect(dto.toJson(), {'role': 'user', 'content': 'Text'});
      expect(dto.toEntity(), entity);
      expect(entity.copyWith(content: 'Other').role, 'user');
      expect(dto.copyWith(content: 'Other').role, 'user');
    },
  );
  test(
    'typed nested tools and draft convert both ways without losing action state',
    () {
      const previous = AssistantDraftPrevious(
        title: 'Old',
        start: null,
        end: '2026-01-01',
        priority: 'MED',
      );
      const draft = AssistantDraft(
        type: 'task_edit_draft',
        workspaceId: 'w',
        projectId: 'p',
        taskId: 't',
        title: 'Title',
        description: 'Desc',
        dueDate: '2026-01-01',
        suggestedAssigneeName: 'Name',
        resolvedAssigneeId: 'u',
        patch: {'title': 'New'},
        previous: previous,
      );
      const result = AssistantToolResult(
        updated: {'workspaceId': 'w'},
        action: {'type': 'open_task'},
        results: [
          42,
          {
            'attachment': {'messageId': 'm'},
          },
        ],
        draft: draft,
        attachment: {'name': 'file'},
      );
      const entity = AssistantMessageModel(
        role: 'assistant',
        content: 'Done',
        images: ['image'],
        tools: [AssistantTool(name: 'prepare_task_edit', result: result)],
        draft: draft,
        actionStates: {'create': 'cancelled'},
      );
      final dto = AssistantMessageDto.fromEntity(entity);
      expect(dto.toEntity(), entity);
      expect(AssistantMessageDto.fromJson(dto.toJson()).toEntity(), entity);
      expect(AssistantDraftDto.fromEntity(draft).toEntity(), draft);
      expect(
        AssistantToolDto.fromEntity(entity.tools.single).toEntity(),
        entity.tools.single,
      );
      expect(AssistantActions.validDraftEdit(draft, 'w'), isTrue);
      expect(previous.value('title'), 'Old');
      expect(previous.value('unknown'), isNull);
    },
  );
  test('DTO-only unknown payload keys survive JSON round trip', () {
    final tool = AssistantToolDto.fromJson({
      'name': 'custom',
      'arguments': {'unknown': 1},
      'result': {'unknown': true},
    });
    expect(tool.toJson()['arguments'], {'unknown': 1});
    expect(AssistantToolDto.fromJson(tool.toJson()), tool);
    final draft = AssistantDraftDto.fromJson({
      'title': 'Title',
      'unknown': 123,
    });
    expect(draft.toJson()['unknown'], 123);
    expect(draft.toEntity().title, 'Title');
  });
  test('explicit null error still marks result as failed', () {
    final result = AssistantToolDto.fromJson({
      'name': 'update_task',
      'result': {'error': null},
    }).toEntity().result!;
    expect(result.error, isNull);
    expect(result.hasError, isTrue);
    expect(
      AssistantToolDto.fromEntity(
        AssistantTool(name: 'update_task', result: result),
      ).toJson()['result'],
      {'error': null},
    );
  });
  test(
    'non-map results remain absent and dynamic result lists retain heterogeneous values',
    () {
      expect(
        AssistantToolDto.fromJson({
          'name': 'custom',
          'result': 123,
        }).toEntity().result,
        isNull,
      );
      final result = AssistantToolDto.fromJson({
        'name': 'custom',
        'result': {
          'results': [
            1,
            'text',
            {'x': true},
          ],
        },
      }).toEntity().result!;
      expect(result.results, [
        1,
        'text',
        {'x': true},
      ]);
    },
  );
  test(
    'invalid draft identity/patch/previous never becomes a valid edit after mapping',
    () {
      final valid = <String, dynamic>{
        'type': 'task_edit_draft',
        'workspaceId': 'w',
        'projectId': 'p',
        'taskId': 't',
        'title': 'Title',
        'patch': {'start': null},
        'previous': {'start': null},
      };
      for (final invalid in <Map<String, dynamic>>[
        {...valid, 'workspaceId': 123},
        {...valid, 'taskId': 42},
        {...valid, 'title': 42},
        {...valid, 'patch': 'invalid'},
        {
          ...valid,
          'previous': {'start': 42},
        },
        {
          ...valid,
          'previous': {
            'start': {'nested': true},
          },
        },
        {...valid, 'previous': null},
        {
          ...valid,
          'patch': {'unknown': true},
        },
      ]) {
        final draft = AssistantDraftDto.fromJson(invalid).toEntity();
        expect(
          AssistantActions.validDraftEdit(draft, 'w'),
          isFalse,
          reason: '$invalid',
        );
      }
    },
  );
}

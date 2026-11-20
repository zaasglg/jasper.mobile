import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/storage/data/models/storage_scope_dto.dart';
import 'package:jospar/features/storage/data/models/storage_item_dto.dart';
import 'package:jospar/features/storage/data/models/storage_summary_dto.dart';
import 'package:jospar/features/storage/data/models/storage_summary_page_dto.dart';
import 'package:jospar/features/storage/data/models/storage_analysis_result_dto.dart';
import 'package:jospar/features/storage/data/models/storage_summary_content_dto.dart';
import 'package:jospar/features/storage/domain/entities/storage_scope.dart';
import 'package:jospar/features/storage/domain/entities/storage_item.dart';
import 'package:jospar/features/storage/domain/entities/storage_summary.dart';
import 'package:jospar/features/storage/domain/entities/storage_summary_page.dart';
import 'package:jospar/features/storage/domain/entities/storage_summary_content.dart';
import 'package:jospar/features/storage/domain/entities/storage_analysis_result.dart';
import 'package:jospar/features/storage/domain/entities/storage_enums.dart';

void main() {
  test('scope enum JSON contract and conversions preserve all fields', () {
    for (final source in StorageSource.values) {
      final entity = StorageScope(
        source: source,
        id: 's',
        workspaceId: 'w',
        title: 'Title',
      );
      final dto = StorageScopeDto.fromEntity(entity);
      expect(dto.toJson(), {
        'source': source.name,
        'id': 's',
        'workspaceId': 'w',
        'title': 'Title',
      });
      expect(dto.toEntity(), entity);
      expect(StorageScopeDto.fromJson(dto.toJson()), dto);
      expect(entity.copyWith(title: 'Other').source, source);
      expect(dto.copyWith(title: 'Other').id, 's');
    }
    expect(
      StorageScopeDto.fromJson({'source': 'unknown', 'id': 123}).source,
      StorageSource.project,
    );
    expect(
      StorageScopeDto.fromJson({}).toEntity(),
      const StorageScope(
        source: StorageSource.project,
        id: '',
        workspaceId: '',
        title: '',
      ),
    );
  });
  test('item conversions preserve all fields and enum kinds', () {
    for (final kind in StorageFileKind.values) {
      final entity = StorageItem(
        id: 'i',
        name: 'file.pdf',
        kind: kind,
        date: DateTime.utc(2026),
        dataUrl: 'data:abc',
        url: 'https://cdn/file',
        sizeLabel: '1 KB',
        authorId: 'u',
        authorName: 'Name',
        taskId: 't',
        taskDisplayId: 'PR-1',
        taskTitle: 'Task',
        messageId: 'm',
        favorited: true,
        mimeType: 'application/pdf',
      );
      final dto = StorageItemDto.fromEntity(entity);
      expect(dto.toEntity(), entity);
      expect(StorageItemDto.fromJson(dto.toJson()), dto);
      expect(dto.toJson()['kind'], kind.name);
      expect(dto.copyWith(name: 'Other').kind, kind);
      expect(entity.copyWith(name: 'Other').date, entity.date);
    }
  });
  test(
    'item defaults, scalar coercion and strict nullable string fields remain unchanged',
    () {
      final dto = StorageItemDto.fromJson({
        'id': 123,
        'name': {'x': 1},
        'kind': 'unknown',
        'date': 'bad',
        'favorited': 'true',
      });
      expect(dto.id, '123');
      expect(dto.name, '{x: 1}');
      expect(dto.kind, StorageFileKind.other);
      expect(dto.date, DateTime.fromMillisecondsSinceEpoch(0));
      expect(dto.favorited, isFalse);
      for (final key in ['dataUrl', 'url', 'taskId', 'messageId']) {
        expect(StorageItemDto.fromJson({key: null}).toJson()[key], isNull);
        expect(
          () => StorageItemDto.fromJson({key: 123}),
          throwsA(isA<TypeError>()),
        );
      }
    },
  );
  test('business getters stay on domain entity', () {
    StorageItem file(StorageFileKind kind, String name) =>
        StorageItem(id: '', name: name, kind: kind, date: DateTime.utc(2026));
    expect(
      file(StorageFileKind.link, 'file.pdf').category,
      StorageCategory.links,
    );
    expect(
      file(StorageFileKind.image, 'file.png').category,
      StorageCategory.media,
    );
    expect(
      file(StorageFileKind.pdf, 'file.pdf').category,
      StorageCategory.documents,
    );
    expect(file(StorageFileKind.pdf, 'file.pdf').canAnalyze, isTrue);
    expect(file(StorageFileKind.link, 'file.pdf').canAnalyze, isFalse);
    expect(file(StorageFileKind.other, 'file.txt').canOpen, isFalse);
    expect(
      file(StorageFileKind.other, 'file.txt').copyWith(messageId: 'm').canOpen,
      isTrue,
    );
  });
  test(
    'summary/page nested conversions preserve typed content and dynamic entries',
    () {
      const content = StorageSummaryContent(
        participantDetails: {
          'u': {'name': 'Name'},
        },
        keyDecisions: [
          {
            'userId': 'u',
            'createdTask': {'id': 't', 'title': 'Task'},
          },
        ],
        allEntries: [
          {
            'id': 'e',
            'file': {
              'dataUrl': 'data:abc',
              'name': 'file.pdf',
              'mimeType': 'application/pdf',
            },
          },
        ],
        duration: '15 минут',
      );
      final summary = StorageSummary(
        id: 's',
        roomId: 'r',
        number: '1',
        authorName: 'Author',
        date: DateTime.utc(2026),
        content: content,
      );
      final page = StorageSummaryPage(items: [summary], total: 1);
      final dto = StorageSummaryPageDto.fromEntity(page);
      expect(dto.toEntity(), page);
      expect(StorageSummaryPageDto.fromJson(dto.toJson()), dto);
      expect(dto.toEntity().items.single.content, content);
      expect(StorageSummaryDto.fromEntity(summary).toEntity(), summary);
      expect(StorageSummaryContentDto.fromEntity(content).toEntity(), content);
      expect(
        content.copyWith(duration: 'Other').allEntries,
        content.allEntries,
      );
      expect(summary.copyWith(number: '2').content, content);
    },
  );
  test(
    'content top level parses defaults, duration text and filters non-map entries',
    () {
      final dto = StorageSummaryContentDto.fromJson({
        'participantDetails': {
          'u': {'name': 'Name'},
        },
        'allEntries': [
          false,
          {'text': 'Entry', 'custom': true},
        ],
        'keyDecisions': [],
        'duration': 123,
        'unknown': true,
      });
      expect(dto.toJson()['duration'], 123);
      expect(dto.toJson()['unknown'], isTrue);
      final entity = dto.toEntity();
      expect(entity.duration, '123');
      expect(entity.allEntries.single['custom'], isTrue);
      expect(
        StorageSummaryContentDto.fromJson({}).toEntity(),
        const StorageSummaryContent(),
      );
      expect(
        StorageSummaryContentDto.fromJson({
          'participantDetails': 'bad',
          'duration': null,
        }).toEntity(),
        const StorageSummaryContent(),
      );
      expect(
        () =>
            StorageSummaryContentDto.fromJson({'allEntries': 'bad'}).toEntity(),
        throwsA(isA<TypeError>()),
      );
    },
  );
  test('summary defaults and nested author date parsing preserve contract', () {
    final dto = StorageSummaryDto.fromJson({
      'id': 123,
      'documentNumber': 42,
      'createdBy': {'name': 'Name'},
      'createdAt': 'bad',
      'content': 'bad',
    });
    expect(dto.id, '123');
    expect(dto.number, '42');
    expect(dto.authorName, 'Name');
    expect(dto.date, DateTime.fromMillisecondsSinceEpoch(0));
    expect(dto.toEntity().content, const StorageSummaryContent());
    expect(
      StorageSummaryPageDto.fromJson({
        'items': [false, {}],
        'total': 3.9,
      }).total,
      3,
    );
    expect(
      StorageSummaryPageDto.fromJson({}).toEntity(),
      const StorageSummaryPage(),
    );
    expect(
      () => StorageSummaryPageDto.fromJson({'items': 'bad'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => StorageSummaryPageDto.fromJson({'total': '3'}),
      throwsA(isA<TypeError>()),
    );
  });
  test('analysis count precedence, flags and conversions remain unchanged', () {
    const entity = StorageAnalysisResult(
      created: 3,
      alreadyImported: true,
      undoBatchId: 'b',
    );
    final dto = StorageAnalysisResultDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(StorageAnalysisResultDto.fromJson(dto.toJson()), dto);
    expect(
      StorageAnalysisResultDto.fromJson({
        'created': 3.9,
        'items': [1],
      }).created,
      3,
    );
    expect(
      StorageAnalysisResultDto.fromJson({
        'items': [1, 2],
        'undoBatchId': 123,
      }).created,
      2,
    );
    expect(
      StorageAnalysisResultDto.fromJson({'undoBatchId': 123}).undoBatchId,
      '123',
    );
    expect(
      StorageAnalysisResultDto.fromJson({}).toEntity(),
      const StorageAnalysisResult(),
    );
    expect(
      () => StorageAnalysisResultDto.fromJson({'created': '3'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => StorageAnalysisResultDto.fromJson({'items': 'bad'}),
      throwsA(isA<TypeError>()),
    );
  });
}

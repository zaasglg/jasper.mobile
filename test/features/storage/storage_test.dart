import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/storage/data/storage_collector.dart';
import 'package:jospar/features/storage/data/storage_models.dart';
import 'package:jospar/features/storage/data/storage_repository_impl.dart';
import 'package:jospar/features/storage/presentation/storage_cubit.dart';
import 'package:jospar/features/storage/domain/storage_repository.dart';

const project = StorageScope(
  source: StorageSource.project,
  id: 'p',
  workspaceId: 'w',
  title: 'Проект',
);
const chat = StorageScope(
  source: StorageSource.chat,
  id: 'thread',
  workspaceId: 'w',
  title: 'Чат',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('overlapping archive results are paged independently', () async {
    final adapter = Adapter((request) {
      if (request.queryParameters['skip'] == 100) return [];
      return List.generate(
        100,
        (i) => {
          'id': 'task-$i',
          'detail': {
            'files': [
              {'id': 'file-$i', 'name': 'file-$i.pdf'},
            ],
          },
        },
      );
    });
    final repo = StorageRepositoryImpl(
      Dio()..httpClientAdapter = adapter,
      const FlutterSecureStorage(),
    );
    expect((await repo.load(project)).length, 100);
    expect(adapter.requests.length, 4);
  });
  for (final archived in [false, true]) {
    test(
      'project storage rejects repeated pages (archived: $archived)',
      () async {
        final adapter = Adapter((request) {
          final current = request.queryParameters['archived'] == 'true';
          if (current != archived) return [];
          if ((request.queryParameters['skip'] as int) >= 200) {
            throw StateError('Pagination did not stop');
          }
          return List.generate(100, (i) => {'id': 'task-$i'});
        });
        final repo = StorageRepositoryImpl(
          Dio()..httpClientAdapter = adapter,
          const FlutterSecureStorage(),
        );
        await expectLater(repo.load(project), throwsA(isA<StorageException>()));
        expect(
          adapter.requests
              .where(
                (r) => r.queryParameters['archived'] == archived.toString(),
              )
              .length,
          2,
        );
      },
    );
  }
  test(
    'project collects comments, deduplicates mirrored files, excludes deleted comments and HTML attributes',
    () {
      final items = StorageCollector.project([
        {
          'id': 't',
          'displayId': 'PR-1',
          'detail': {
            'description':
                '<p><a href="https://example.com?a=1&amp;b=2">ссылка</a><img src="https://hidden.com/image"> https://visible.com.</p>',
            'files': [
              {
                'id': 'cfile__c__0',
                'name': 'report.pdf',
                'dataUrl': 'data:application/pdf;base64,YQ==',
              },
            ],
            'comments': [
              {
                'id': 'c',
                'author': 'Алия',
                'files': [
                  {'name': 'report.pdf'},
                ],
                'text': 'https://comment.com',
              },
              {
                'id': 'deleted',
                'deletedAt': '2026-10-30',
                'files': [
                  {'name': 'secret.png'},
                ],
              },
            ],
          },
        },
      ]);
      expect(items.where((e) => e.name == 'report.pdf').length, 1);
      expect(items.firstWhere((e) => e.name == 'report.pdf').id, 'cfile:t:c:0');
      expect(
        items.where((e) => e.kind == StorageFileKind.link).map((e) => e.url),
        containsAll([
          'https://example.com?a=1&b=2',
          'https://visible.com',
          'https://comment.com',
        ]),
      );
      expect(
        items.any((e) => e.name.contains('hidden') || e.name == 'secret.png'),
        false,
      );
      expect(
        items.every((e) => e.taskId == 't' && e.taskDisplayId == 'PR-1'),
        true,
      );
    },
  );
  test(
    'chat parses captioned file and Drive link while retaining lazy attachment identity',
    () {
      final items = StorageCollector.chat([
        {
          'id': 'm',
          'text': 'Посмотрите\n\n📎 photo.png · 12 КБ',
          'userId': 'u',
          'favorited': true,
        },
        {'id': 'l', 'text': '📊 План — https://docs.google.com/sheet'},
        {'id': 'plain', 'text': 'https://ordinary.com'},
      ]);
      expect(items.length, 2);
      final file = items.firstWhere((e) => e.id == 'm');
      expect(file.kind, StorageFileKind.image);
      expect(file.canOpen, true);
      expect(file.dataUrl, null);
      expect(file.favorited, true);
      expect(
        items.firstWhere((e) => e.id == 'l').category,
        StorageCategory.links,
      );
    },
  );
  test(
    'project repository loads active and archived pages with full detail and scope',
    () async {
      final adapter = Adapter((r) {
        if (r.path == 'project-tasks') {
          if (r.queryParameters['archived'] == 'true') {
            return [
              {
                'id': 'archived',
                'detail': {
                  'files': [
                    {'id': 'f', 'name': 'archive.pdf'},
                  ],
                },
              },
            ];
          }
          if (r.queryParameters['skip'] == 0) {
            return List.generate(100, (i) => {'id': 't$i'});
          }
          return [
            {
              'id': 'last',
              'detail': {
                'files': [
                  {'id': 'f', 'name': 'last.png'},
                ],
              },
            },
          ];
        }
        return {'id': 'u'};
      });
      final repo = StorageRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const FlutterSecureStorage(),
      );
      final items = await repo.load(project);
      expect(
        items.map((e) => e.name),
        containsAll(['last.png', 'archive.pdf']),
      );
      expect(
        adapter.requests.where((e) => e.path == 'project-tasks').length,
        3,
      );
      expect(
        adapter.requests.every((e) => e.headers['X-Workspace-Id'] == 'w'),
        true,
      );
      expect(
        adapter.requests.any((e) => e.queryParameters['board'] == true),
        false,
      );
    },
  );
  test(
    'chat pagination includes older attachments and avoids duplicate ids',
    () async {
      final adapter = Adapter(
        (r) => r.queryParameters['cursor'] == null
            ? {
                'data': [
                  {'id': 'new', 'text': '📎 new.pdf · 1 КБ'},
                ],
                'nextCursor': 'older',
              }
            : {
                'data': [
                  {'id': 'old', 'text': '📎 old.pdf · 1 КБ'},
                  {'id': 'new', 'text': '📎 new.pdf · 1 КБ'},
                ],
                'nextCursor': null,
              },
      );
      final repo = StorageRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const FlutterSecureStorage(),
      );
      expect((await repo.load(chat)).length, 2);
      expect(adapter.requests.last.queryParameters['cursor'], 'older');
      expect(
        adapter.requests.every(
          (e) => e.queryParameters['threadId'] == 'thread',
        ),
        true,
      );
    },
  );
  test(
    'project favorites survive reopening and are isolated by account and workspace',
    () async {
      var user = 'u';
      final repo = StorageRepositoryImpl(
        Dio()..httpClientAdapter = Adapter((_) => {'id': user}),
        const FlutterSecureStorage(),
      );
      final item = StorageItem(
        id: 'f',
        name: 'f.pdf',
        kind: StorageFileKind.pdf,
        date: DateTime(2026),
      );
      await repo.setFavorite(project, item, true);
      expect(await repo.favorites(project), {'f'});
      expect(
        await repo.favorites(project.copyWith(workspaceId: 'other')),
        isEmpty,
      );
      user = 'other';
      expect(await repo.favorites(project), isEmpty);
      user = 'u';
      expect(await repo.favorites(project), {'f'});
    },
  );
  test('signed downloads never receive API authentication headers', () async {
    final api = Adapter((_) => throw StateError('API should not be used'));
    final cdn = Adapter((r) {
      expect(r.headers.containsKey('Authorization'), false);
      expect(r.headers.containsKey('X-Workspace-Id'), false);
      return [1, 2, 3];
    }, binary: true);
    final repo = StorageRepositoryImpl(
      Dio(BaseOptions(headers: {'Authorization': 'Bearer secret'}))
        ..httpClientAdapter = api,
      const FlutterSecureStorage(),
      downloadDio: Dio()..httpClientAdapter = cdn,
    );
    final bytes = await repo.bytes(
      project,
      StorageItem(
        id: 'f',
        name: 'f.pdf',
        kind: StorageFileKind.pdf,
        date: DateTime(2026),
        dataUrl: 'https://cdn.example.com/f?signature=abc',
      ),
    );
    expect(bytes, [1, 2, 3]);
    expect(api.requests, isEmpty);
  });
  test(
    'failed favorite mutation retains selection and refresh error preserves loaded files',
    () async {
      var fail = false;
      final adapter = Adapter((r) {
        if (r.path == 'users/me') return {'id': 'u'};
        if (fail) {
          throw DioException(
            requestOptions: r,
            response: Response(requestOptions: r, statusCode: 403),
          );
        }
        return {
          'data': [
            {'id': 'm', 'userId': 'u', 'text': '📎 a.pdf · 1 КБ'},
          ],
        };
      });
      final cubit = StorageCubit(
        StorageRepositoryImpl(
          Dio()..httpClientAdapter = adapter,
          const FlutterSecureStorage(),
        ),
        chat,
      );
      await cubit.load();
      expect(cubit.state.items.length, 1);
      fail = true;
      await cubit.favorite(cubit.state.items.first);
      expect(cubit.state.favorites, isEmpty);
      expect(cubit.state.error, 'Нет доступа к этим файлам');
      await cubit.load();
      expect(cubit.state.items.length, 1);
      expect(cubit.state.loading, false);
      await cubit.close();
    },
  );
  test(
    'analysis uses job result, workspace timezone and allows undo',
    () async {
      final adapter = Adapter(
        (r) => switch (r.path) {
          'ocr/jobs' => {'id': 'job'},
          'ocr/jobs/job' => {'status': 'completed'},
          'ocr/jobs/job/result' => {
            'text': 'Сделать задачу',
            'sourceHash': 'a' * 64,
          },
          'workspaces/w' => {'timeZone': 'Asia/Almaty'},
          'ocr/tasks' => {
            'items': [
              {'id': 'task'},
            ],
            'undoBatchId': 'batch',
          },
          'ocr/tasks/undo' => {'success': true},
          _ => throw StateError(r.path),
        },
      );
      final repo = StorageRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const FlutterSecureStorage(),
      );
      final result = await repo.analyze(
        project,
        StorageItem(
          id: 'f',
          name: 'f.pdf',
          kind: StorageFileKind.pdf,
          date: DateTime(2026),
          dataUrl: 'data:application/pdf;base64,YQ==',
        ),
      );
      expect(result.created, 1);
      final body =
          adapter.requests.firstWhere((e) => e.path == 'ocr/tasks').data as Map;
      expect(body['workspaceId'], 'w');
      expect(body['timeZone'], 'Asia/Almaty');
      expect(body.containsKey('sourceFile'), false);
      await repo.undoImport(project, result.undoBatchId!);
      expect((adapter.requests.last.data as Map)['batchId'], 'batch');
    },
  );
}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond, {this.binary = false});
  final Object Function(RequestOptions) respond;
  final bool binary;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = respond(options);
    if (binary) {
      return ResponseBody.fromBytes((result as List).cast<int>(), 200);
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

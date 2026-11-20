import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/storage/data/storage_repository_impl.dart';
import 'package:jospar/features/storage/domain/entities/storage_scope.dart';
import 'package:jospar/features/storage/domain/entities/storage_enums.dart';
import 'package:jospar/features/storage/domain/entities/storage_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'summary list and content preserve HTTP paths, pagination and workspace header',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final requests = <RequestOptions>[];
      final created = DateTime.utc(2026).toIso8601String();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': request.path == 'video/thread-summaries'
                      ? {
                          'items': [
                            {
                              'id': 'a/b',
                              'roomId': 'r/s',
                              'documentNumber': '1',
                              'createdAt': created,
                            },
                          ],
                          'total': 1,
                        }
                      : {
                          'content': {
                            'participantDetails': {
                              'u': {'name': 'Name'},
                            },
                            'allEntries': [
                              {'text': 'Text'},
                            ],
                            'duration': 42,
                          },
                        },
                },
              ),
            );
          },
        ),
      );
      final repository = StorageRepositoryImpl(
        dio,
        const FlutterSecureStorage(),
      );
      const scope = StorageScope(
        source: StorageSource.chat,
        id: 'thread',
        workspaceId: 'w',
        title: 'Chat',
      );
      final page = await repository.summaries(scope, 20);
      expect(page.items.single, isA<StorageSummary>());
      expect(requests.first.queryParameters, {
        'threadId': 'thread',
        'workspaceId': 'w',
        'skip': 20,
        'take': 20,
      });
      final summary = await repository.summary(scope, page.items.single);
      expect(summary.content.duration, '42');
      expect(summary.content.allEntries.single['text'], 'Text');
      expect(summary.content.participantDetails['u'], {'name': 'Name'});
      expect(requests.map((r) => r.path), [
        'video/thread-summaries',
        'video/rooms/r%2Fs/summaries/a%2Fb',
      ]);
      expect(
        requests.every(
          (r) => r.method == 'GET' && r.headers['X-Workspace-Id'] == 'w',
        ),
        isTrue,
      );
    },
  );
}

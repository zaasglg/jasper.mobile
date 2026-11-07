import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/search/data/search_repository.dart';

void main() {
  test(
    'loads all active and archived pages independently and keeps workspace scope',
    () async {
      final adapter = _Adapter(active: 137, archived: 103);
      final result = await _repo(adapter).search('  task  ', 'w');
      expect(result.tasks.length, 240);
      expect(result.tasks.where((t) => t.archived).length, 103);
      expect(result.tasks.any((t) => t.id == 'active-136'), isTrue);
      expect(result.tasks.any((t) => t.id == 'archive-102'), isTrue);
      expect(result.failedSources, isEmpty);
      for (final archived in [false, true]) {
        final requests = adapter.taskRequests.where(
          (r) => r.queryParameters['archived'] == archived,
        );
        expect(requests.map((r) => r.queryParameters['skip']), [0, 50, 100]);
        expect(
          requests.every(
            (r) =>
                r.queryParameters['take'] == 50 &&
                r.queryParameters['search'] == 'task' &&
                r.queryParameters['projectIds'] == 'p',
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'exact full page requests terminal empty page; duplicates are removed',
    () async {
      final adapter = _Adapter(active: 100, archived: 0)..duplicate = true;
      final result = await _repo(adapter).search('task', 'w');
      expect(result.tasks.length, 99);
      expect(
        adapter.taskRequests
            .where((r) => r.queryParameters['archived'] == false)
            .map((r) => r.queryParameters['skip']),
        [0, 50, 100],
      );
      expect(result.failedSources, isEmpty);
    },
  );
  test(
    'later page failure preserves earlier results and the other source',
    () async {
      final adapter = _Adapter(active: 120, archived: 60)
        ..failSecondActive = true;
      final result = await _repo(adapter).search('task', 'w');
      expect(result.tasks.where((t) => !t.archived).length, 50);
      expect(result.tasks.where((t) => t.archived).length, 60);
      expect(result.failedSources, ['Задачи']);
    },
  );
  test(
    'server ignoring skip cannot loop indefinitely or silently truncate',
    () async {
      final adapter = _Adapter(active: 100, archived: 0)..repeat = true;
      final result = await _repo(adapter).search('task', 'w');
      expect(result.tasks.length, 50);
      expect(result.failedSources, ['Задачи']);
      expect(
        adapter.taskRequests
            .where((r) => r.queryParameters['archived'] == false)
            .length,
        2,
      );
    },
  );
  test('cancelling between pages aborts remaining search requests', () async {
    final token = CancelToken();
    final adapter = _Adapter(active: 120, archived: 0)
      ..cancelAfterFirst = token;
    await expectLater(
      _repo(adapter).search('task', 'w', cancelToken: token),
      throwsA(
        isA<DioException>().having(CancelToken.isCancel, 'cancelled', true),
      ),
    );
    expect(
      adapter.taskRequests.every((r) => r.queryParameters['skip'] == 0),
      isTrue,
    );
  });
}

SearchRepositoryImpl _repo(_Adapter adapter) => SearchRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = adapter,
);

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.active, required this.archived});
  final int active, archived;
  final requests = <RequestOptions>[];
  bool failSecondActive = false, repeat = false, duplicate = false;
  CancelToken? cancelAfterFirst;
  Iterable<RequestOptions> get taskRequests =>
      requests.where((r) => r.path == 'project-tasks');
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object data;
    var code = 200;
    if (options.path == 'projects') {
      data = [
        {'id': 'p', 'name': 'Project', 'workspaceId': 'w'},
        {'id': 'other', 'name': 'Other', 'workspaceId': 'elsewhere'},
      ];
    } else if (options.path == 'inbox') {
      data = [];
    } else {
      final archive = options.queryParameters['archived'] == true;
      final skip = options.queryParameters['skip'] as int;
      final start = repeat ? 0 : skip;
      final count = archive ? archived : active;
      if (failSecondActive && !archive && skip > 0) {
        code = 503;
        data = {};
      } else {
        data = {
          'data': [
            for (var i = start; i < count && i < start + 50; i++)
              {
                'id':
                    '${archive ? 'archive' : 'active'}-${duplicate && i == 50 ? 49 : i}',
                'projectId': 'p',
                'title': 'Task $i',
                'status': 'TODO',
              },
          ],
        };
      }
      if (!archive && skip == 0) cancelAfterFirst?.cancel('Query changed');
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

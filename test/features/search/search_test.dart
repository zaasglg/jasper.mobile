import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/search/data/search_repository.dart';
import 'package:jospar/features/search/presentation/search_cubit.dart';
import 'package:jospar/features/search/presentation/search_screen.dart';

void main() {
  test('search uses documented parameters and scopes project tasks', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final result = await SearchRepositoryImpl(dio).search('отчёт', 'workspace');
    expect(result.tasks.map((task) => task.id), ['active', 'archived']);
    expect(result.tasks.last.archived, isTrue);
    expect(result.inbox.single.title, 'Отчёт для Инбокса');
    expect(result.projects.single.id, 'project');
    expect(result.failedSources, isEmpty);
    final requests = adapter.requests.where(
      (request) => request.path == 'project-tasks',
    );
    expect(requests.length, 2);
    expect(
      requests.every(
        (request) =>
            request.queryParameters['projectIds'] == 'project' &&
            request.queryParameters['search'] == 'отчёт',
      ),
      isTrue,
    );
  });

  test(
    'stale responses cannot overwrite the latest query or cleared search',
    () async {
      final repository = _Repository();
      final cubit = SearchCubit(repository, 'workspace');
      addTearDown(cubit.close);
      cubit.changeQuery('старый', immediate: true);
      cubit.changeQuery('новый', immediate: true);
      repository.pending['новый']!.complete(const SearchResults());
      await Future<void>.delayed(Duration.zero);
      repository.pending['старый']!.complete(const SearchResults());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.query, 'новый');
      cubit.changeQuery('ещё', immediate: true);
      cubit.changeQuery('');
      repository.pending['ещё']!.complete(const SearchResults());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SearchStatus.initial);
    },
  );

  testWidgets('search waits for typing, displays results and clears', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = SearchCubit(repository, 'workspace');
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byKey(const Key('global-search-input')), 'от');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const Key('global-search-input')),
      'отчёт',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.pending, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.pending.keys, ['отчёт']);
    repository.pending['отчёт']!.complete(
      const SearchResults(
        projects: [
          ProjectModel(
            id: 'project',
            name: 'Отчёт команды',
            code: 'REP',
            workspaceId: 'workspace',
            start: null,
            end: null,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Отчёт команды'), findsOneWidget);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Найдите нужное'), findsOneWidget);
    expect(find.text('Отчёт команды'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements SearchRepository {
  final pending = <String, Completer<SearchResults>>{};
  @override
  Future<SearchResults> search(
    String query,
    String workspaceId, {
    CancelToken? cancelToken,
  }) => (pending[query] = Completer<SearchResults>()).future;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final dynamic result;
    switch (options.path) {
      case 'projects':
        result = [
          {
            'id': 'project',
            'name': 'Отчёт команды',
            'workspaceId': 'workspace',
          },
          {
            'id': 'other',
            'name': 'Отчёт другой команды',
            'workspaceId': 'other',
          },
        ];
      case 'inbox':
        result = [
          {'id': 'inbox', 'title': 'Отчёт для Инбокса'},
          {'id': 'irrelevant', 'title': 'Другое'},
        ];
      default:
        result = {
          'data': [
            {
              'id': options.queryParameters['archived'] == true
                  ? 'archived'
                  : 'active',
              'title': 'Отчёт',
              'projectId': 'project',
              'status': 'TODO',
            },
            {
              'id': 'out-of-scope',
              'title': 'Отчёт',
              'projectId': 'other',
              'status': 'TODO',
            },
          ],
        };
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

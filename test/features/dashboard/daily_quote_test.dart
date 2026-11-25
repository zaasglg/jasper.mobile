import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/data/daily_quote_repository_impl.dart';
import 'package:jospar/features/dashboard/domain/daily_quote_repository.dart';
import 'package:jospar/features/dashboard/domain/entities/daily_quote.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_daily_quote.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'quote': {'text': 'Текст', 'author': 'Автор'},
        'refreshing': true,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Quotes implements DailyQuoteRepository {
  final replies = <String, Completer<DailyQuote>>{};
  @override
  Future<DailyQuote> load(String workspaceId) =>
      (replies[workspaceId] ??= Completer<DailyQuote>()).future;
}

void main() {
  test('uses the web daily motivation contract with workspace scope', () async {
    final adapter = _Adapter();
    final repository = DailyQuoteRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter,
    );
    final quote = await repository.load('one');
    expect(adapter.request!.path, 'ai/daily-motivation');
    expect(adapter.request!.queryParameters, {'workspaceId': 'one'});
    expect(adapter.request!.headers['X-Workspace-Id'], 'one');
    expect(quote.text, 'Текст');
    expect(quote.author, 'Автор');
    expect(quote.refreshing, isTrue);
    expect(DailyQuote.fromJson(quote.toJson()), quote);
    expect(
      () => DailyQuote.fromJson({
        'quote': {'text': ' ', 'author': 'Автор'},
      }),
      throwsFormatException,
    );
  });
  testWidgets(
    'switching workspace discards a delayed quote from the old scope',
    (tester) async {
      final repository = _Quotes();
      Widget app(String workspace) => MaterialApp(
        home: Scaffold(
          body: DashboardDailyQuote(
            repository: repository,
            workspaceId: workspace,
          ),
        ),
      );
      await tester.pumpWidget(app('one'));
      await tester.pumpWidget(app('two'));
      repository.replies['two']!.complete(
        const DailyQuote(text: 'Новая цитата', author: 'Новый автор'),
      );
      await tester.pumpAndSettle();
      expect(find.text('«Новая цитата»'), findsOneWidget);
      repository.replies['one']!.complete(
        const DailyQuote(text: 'Старая цитата', author: 'Прежний автор'),
      );
      await tester.pumpAndSettle();
      expect(find.text('«Старая цитата»'), findsNothing);
      expect(find.text('Новый автор'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quote failure keeps dashboard clean and long text fits compact dark screens',
    (tester) async {
      final repository = _Quotes();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: DashboardDailyQuote(
                  repository: repository,
                  workspaceId: 'one',
                ),
              ),
            ),
          ),
        ),
      );
      repository.replies['one']!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-daily-quote')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      repository.replies.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repository.replies['one']!.complete(
        DailyQuote(
          text: List.filled(30, 'Длинная цитата').join(' '),
          author: 'Автор',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Автор'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

import 'planner_test_app.dart';

const _title = 'Язык при выборе времени в ежедневнике';

class _Api implements HttpClientAdapter {
  int? rejection;
  Object message = 'Недостаточно прав';
  bool retained = false;
  bool deleted = false;
  bool failRefresh = false;
  Completer<void>? gate;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      await gate?.future;
      if (rejection != null) return _json({'message': message}, rejection!);
      deleted = true;
      return ResponseBody.fromString('', 204);
    }
    if (options.path == 'project-planner/account') {
      if (deleted && failRefresh) return _json({}, 500);
      return _json(
        deleted && !retained
            ? []
            : [
                {
                  'id': 'planner-slot',
                  'projectId': 'project',
                  'taskId': 'original-task',
                  'scheduledAt': null,
                  'task': {
                    'id': 'original-task',
                    'projectId': 'project',
                    'displayId': 'МО-98',
                    'title': _title,
                    'status': 'TODO',
                  },
                },
              ],
      );
    }
    throw StateError('Unexpected request: ${options.method} ${options.path}');
  }

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

PlannerRepositoryImpl _repository(_Api api) => PlannerRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = api,
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final status in [403, 404, 409, 500]) {
    test(
      'delete failure exposes HTTP $status without deleting the source task',
      () async {
        final api = _Api()
          ..rejection = status
          ..message = ['Запись заблокирована', 'Повторите позже'];
        await expectLater(
          _repository(api).remove('planner-slot'),
          throwsA(
            isA<PlannerException>().having(
              (e) => e.message,
              'message',
              contains('HTTP $status'),
            ),
          ),
        );
        expect(api.deleted, isFalse);
        expect(api.requests.single.method, 'DELETE');
        expect(api.requests.single.path, 'project-planner/items/planner-slot');
      },
    );
  }

  testWidgets(
    'unscheduled deletion reports failure inside the sheet and retries successfully',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api()
        ..rejection = 403
        ..gate = Completer<void>();
      final cubit = PlannerCubit(_repository(api));
      addTearDown(cubit.close);
      await tester.pumpWidget(
        PlannerTestApp(
          child: BlocProvider.value(
            value: cubit,
            child: const MaterialApp(home: PlannerScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('planner-unscheduled-planner-slot')),
      );
      await tester.pumpAndSettle();
      final remove = find.byKey(const Key('planner-remove'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<TextButton>(remove).onPressed, isNull);
      expect(find.text('Удаление…'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'DELETE').length, 1);
      api.gate!.complete();
      await tester.pumpAndSettle();
      final error = find.byKey(const Key('planner-remove-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, contains('HTTP 403'));
      expect(find.byKey(const Key('planner-editor-title')), findsOneWidget);
      expect(cubit.state.items.single.id, 'planner-slot');
      expect(tester.widget<TextButton>(remove).onPressed, isNotNull);
      await tester.ensureVisible(error);
      expect(
        tester.getRect(error).overlaps(const Rect.fromLTWH(0, 0, 360, 800)),
        isTrue,
      );
      api.rejection = null;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-editor-title')), findsNothing);
      expect(find.textContaining(_title), findsNothing);
      expect(cubit.state.items, isEmpty);
      final refreshed = cubit.refresh();
      await tester.pumpAndSettle();
      await refreshed;
      expect(cubit.state.items, isEmpty);
      expect(
        api.requests.where((r) => r.method == 'DELETE').map((r) => r.path),
        everyElement('project-planner/items/planner-slot'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'server returning the deleted item is reported instead of confirming success',
    () async {
      final api = _Api()..retained = true;
      final cubit = PlannerCubit(_repository(api));
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(await cubit.remove(cubit.state.items.single), isFalse);
      expect(cubit.state.items.single.id, 'planner-slot');
      expect(cubit.state.actionError, contains('Сервер снова вернул запись'));
      expect(cubit.state.busyIds, isEmpty);
    },
  );

  test(
    'failed reload does not turn acknowledged deletion into a failed delete',
    () async {
      final api = _Api()..failRefresh = true;
      final cubit = PlannerCubit(_repository(api));
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(await cubit.remove(cubit.state.items.single), isTrue);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.error, isNotNull);
      expect(api.requests.where((r) => r.method == 'DELETE').length, 1);
    },
  );
}

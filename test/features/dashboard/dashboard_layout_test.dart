import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/data/dashboard_layout.dart';
import 'package:jospar/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:jospar/features/dashboard/domain/dashboard_repository.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';

DashboardLayout fixture() => DashboardLayout.parse({
  'layout': {
    'version': 2,
    'unknown': {'keep': true},
    'widgets': [
      {
        'id': 'tasks-summary',
        'instanceId': 'scrum-custom',
        'visible': true,
        'size': 'half',
        'mode': 'epic',
        'projectIds': ['p'],
        'custom': 'keep',
      },
      {
        'id': 'resource',
        'instanceId': 'resource-custom',
        'visible': true,
        'size': 'third',
        'resourceModeByProject': {'p': 'selected'},
        'resourceNamesByProject': {
          'p': ['["План","Факт"]'],
        },
      },
      {
        'id': 'future-widget',
        'instanceId': 'future',
        'visible': true,
        'extra': 42,
      },
    ],
    'layouts': {
      'lg': [
        {
          'i': 'scrum-custom',
          'x': 6,
          'y': 5,
          'w': 6,
          'h': 14,
          'customGrid': true,
        },
        {'i': 'resource-custom', 'x': 0, 'y': 20, 'w': 4, 'h': 20},
      ],
      'md': [
        {'i': 'scrum-custom', 'x': 4, 'y': 3, 'w': 4, 'h': 14},
      ],
      'sm': [
        {'i': 'scrum-custom', 'x': 0, 'y': 20, 'w': 1, 'h': 14},
        {'i': 'resource-custom', 'x': 0, 'y': 0, 'w': 1, 'h': 20},
      ],
    },
  },
});
void main() {
  test(
    'uses web defaults and normalizes legacy layouts without losing unknown preferences',
    () {
      expect(DashboardLayout.parse(null).widgets.length, 10);
      final layout = fixture();
      expect(layout.ordered.first.instanceId, 'resource-custom');
      expect(
        layout.widgets
            .firstWhere((e) => e.instanceId == 'scrum-custom')
            .options['mode'],
        'epic',
      );
      expect(layout.toJson()['unknown'], {'keep': true});
      expect(
        layout.widgets
            .firstWhere((e) => e.id == 'future-widget')
            .options['extra'],
        42,
      );
      final legacy = DashboardLayout.parse([
        {'id': 'my-tasks', 'visible': false},
      ]);
      expect(legacy.widgets.first.instanceId, 'my-tasks');
      expect(legacy.widgets.first.visible, false);
      expect(legacy.widgets.any((e) => e.id == 'daily-motivation'), true);
      expect(
        () => DashboardLayout.parse({'layout': {}}),
        throwsFormatException,
      );
    },
  );
  test(
    'mobile reorder preserves desktop coordinates and unrelated widget fields',
    () {
      final old = fixture();
      final slots = old.ordered;
      final moved = [slots[1], slots[0], ...slots.skip(2)];
      final next = old.withWidgets(moved);
      final lg = next.layouts['lg'] as List;
      final oldLg = old.layouts['lg'] as List;
      expect(lg.firstWhere((e) => e['i'] == 'scrum-custom'), oldLg.first);
      expect(lg.firstWhere((e) => e['i'] == 'resource-custom'), oldLg.last);
      expect(
        (next.layouts['md'] as List).firstWhere(
          (e) => e['i'] == 'scrum-custom',
        ),
        (old.layouts['md'] as List).first,
      );
      expect(next.ordered.first.instanceId, 'scrum-custom');
      expect(next.widgets.first.options['custom'], 'keep');
      expect(
        next.widgets
            .firstWhere((e) => e.id == 'resource')
            .options['resourceNamesByProject'],
        {
          'p': ['["План","Факт"]'],
        },
      );
    },
  );
  test(
    'explicit resize changes only selected desktop widget, keeping other coordinates',
    () {
      final old = fixture();
      final next = old.withWidgets(
        old.ordered
            .map(
              (e) => e.instanceId == 'scrum-custom'
                  ? e.copyWith(size: 'full', height: 500)
                  : e,
            )
            .toList(),
        resized: {'scrum-custom'},
      );
      final lg = next.layouts['lg'] as List;
      expect(
        lg.firstWhere((e) => e['i'] == 'resource-custom'),
        (old.layouts['lg'] as List).last,
      );
      expect(lg.firstWhere((e) => e['i'] == 'scrum-custom')['w'], 12);
      expect(lg.firstWhere((e) => e['i'] == 'scrum-custom')['h'], 22);
    },
  );
  test(
    'draft cancel does not persist, singletons cannot duplicate and duplicated types can',
    () async {
      final repository = FakeDashboardRepository();
      final cubit = DashboardLayoutCubit(repository);
      await cubit.configure('u', 'w');
      final old = cubit.state.layout;
      cubit.enterEdit();
      cubit.update('my-tasks', {'visible': false});
      cubit.add('my-tasks');
      cubit.add('my-tasks');
      expect(
        cubit.state.current!.widgets.where((e) => e.id == 'my-tasks').length,
        1,
      );
      cubit.add('tasks-summary');
      expect(
        cubit.state.current!.widgets
            .where((e) => e.id == 'tasks-summary')
            .length,
        2,
      );
      cubit.cancelEdit();
      expect(cubit.state.layout, old);
      expect(repository.saved, isEmpty);
      await cubit.close();
    },
  );
  test('reorder uses the final index in both directions', () async {
    final cubit = DashboardLayoutCubit(FakeDashboardRepository());
    addTearDown(cubit.close);
    await cubit.configure('u', 'w');
    cubit.enterEdit();
    List<String> visibleIds() => cubit.state.current!.ordered
        .where((slot) => slot.visible && slot.definition != null)
        .map((slot) => slot.instanceId)
        .toList();
    final original = visibleIds();
    expect(original.length, greaterThan(2));
    cubit.reorder(0, original.length - 1);
    expect(visibleIds(), [...original.skip(1), original.first]);
    cubit.reorder(original.length - 1, 0);
    expect(visibleIds(), original);
    cubit.reorder(0, 1);
    expect(visibleIds(), [original[1], original[0], ...original.skip(2)]);
    cubit.reorder(1, 0);
    expect(visibleIds(), original);
    cubit.reorder(0, original.length);
    expect(visibleIds(), original);
  });
  test(
    'failed save keeps editing and draft, successful retry saves shared v2 layout',
    () async {
      final repository = FakeDashboardRepository();
      final cubit = DashboardLayoutCubit(repository);
      await cubit.configure('u', 'w');
      cubit.enterEdit();
      cubit.update('my-tasks', {'visible': false});
      repository.fail = true;
      expect(await cubit.save(), false);
      expect(cubit.state.editing, true);
      expect(
        cubit.state.current!.widgets
            .firstWhere((e) => e.id == 'my-tasks')
            .visible,
        false,
      );
      expect(
        cubit.state.layout!.widgets
            .firstWhere((e) => e.id == 'my-tasks')
            .visible,
        true,
      );
      repository.fail = false;
      expect(await cubit.save(), true);
      expect(cubit.state.editing, false);
      expect(repository.saved.single.$1, 'w');
      expect(repository.saved.single.$2.toJson()['version'], 2);
      await cubit.close();
    },
  );
  test(
    'server conflict blocks overwriting edits from another device',
    () async {
      final repository = FakeDashboardRepository();
      final cubit = DashboardLayoutCubit(repository);
      await cubit.configure('u', 'w');
      cubit.enterEdit();
      cubit.update('my-tasks', {'visible': false});
      repository.value = repository.value.copyWith(
        extra: {'changedElsewhere': true},
      );
      expect(await cubit.save(), false);
      expect(repository.saved, isEmpty);
      expect(cubit.state.editing, true);
      expect(cubit.state.error, contains('другом устройстве'));
      await cubit.close();
    },
  );
  test(
    'workspace switch discards draft and ignores previous workspace late response',
    () async {
      final repository = FakeDashboardRepository();
      final old = Completer<DashboardLayout>();
      repository.pending['a'] = old;
      final cubit = DashboardLayoutCubit(repository);
      final first = cubit.configure('u', 'a');
      await cubit.configure('u', 'b');
      cubit.enterEdit();
      cubit.update('my-tasks', {'visible': false});
      old.complete(fixture());
      await first;
      expect(cubit.state.workspaceId, 'b');
      expect(
        cubit.state.current!.widgets
            .firstWhere((e) => e.id == 'my-tasks')
            .visible,
        false,
      );
      await cubit.configure('another-user', 'b');
      expect(cubit.state.editing, false);
      expect(
        cubit.state.current!.widgets
            .firstWhere((e) => e.id == 'my-tasks')
            .visible,
        true,
      );
      await cubit.close();
    },
  );
  test(
    'background synchronization updates viewed layout but does not overwrite draft',
    () async {
      final repository = FakeDashboardRepository();
      final cubit = DashboardLayoutCubit(repository);
      await cubit.configure('u', 'w');
      repository.value = fixture();
      await cubit.refreshConfig();
      expect(cubit.state.layout, fixture());
      cubit.enterEdit();
      repository.value = DashboardLayout.defaults();
      await cubit.refreshConfig();
      expect(cubit.state.current, fixture());
      await cubit.close();
    },
  );
  test(
    'API contract scopes both read/write and paginates workspace tasks',
    () async {
      final adapter = DashboardAdapter();
      final repository = DashboardRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final layout = await repository.load('w');
      await repository.save('w', layout);
      expect(adapter.requests[0].queryParameters['workspaceId'], 'w');
      expect(adapter.requests[1].method, 'PUT');
      expect((adapter.requests[1].data as Map)['workspaceId'], 'w');
      expect((adapter.requests[1].data as Map)['layout']['version'], 2);
      expect(
        adapter.requests.every((e) => e.headers['X-Workspace-Id'] == 'w'),
        true,
      );
      final tasks = await repository.tasks('w', ['p']);
      expect(tasks.length, 101);
      expect(
        adapter.requests
            .lastWhere((r) => r.path == 'project-tasks')
            .queryParameters['skip'],
        100,
      );
      expect(
        adapter.requests
            .lastWhere((r) => r.path == 'project-tasks')
            .queryParameters['projectIds'],
        'p',
      );
      expect(tasks.every((e) => e['projectId'] == 'p'), true);
    },
  );
}

class FakeDashboardRepository implements DashboardRepository {
  DashboardLayout value = DashboardLayout.defaults();
  bool fail = false;
  final saved = <(String, DashboardLayout)>[];
  final pending = <String, Completer<DashboardLayout>>{};
  @override
  Future<DashboardLayout> load(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async => pending[workspaceId]?.future ?? value;
  @override
  Future<DashboardLayout> save(
    String workspaceId,
    DashboardLayout layout,
  ) async {
    if (fail) throw const DashboardException('Не удалось сохранить');
    saved.add((workspaceId, layout));
    return value = DashboardLayout.parse(layout.toJson());
  }

  @override
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  ) async => [];
  @override
  Future<dynamic> widgetData(String workspaceId, String kind) async => [];
}

class DashboardAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final dynamic result;
    if (options.path == 'dashboard/config') {
      result = {
        'layout': options.method == 'PUT' ? options.data['layout'] : null,
      };
    } else if (options.queryParameters['skip'] == 0) {
      result = List.generate(100, (i) => {'id': '$i', 'projectId': 'p'});
    } else {
      result = [
        {'id': 'last', 'projectId': 'p'},
      ];
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

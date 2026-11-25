import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/task_icon_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/repositories/task_icon_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_state.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_task_symbol.dart';

class Items implements PlannerRepository {
  @override
  Future<void> updateExtras(
    String itemId, {
    bool updateIcon = false,
    String? icon,
    List<TaskChecklistModel>? checklists,
  }) async {}

  List<PlannerItemModel> items = [
    const PlannerItemModel(id: 'one', title: 'Код'),
  ];
  @override
  Future<List<PlannerItemModel>> load() async => items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IconsRepository implements TaskIconRepository {
  int calls = 0;
  final pending = Completer<Map<String, String>>();
  @override
  Future<Map<String, String>> getIcons(List<String> titles) {
    calls++;
    return pending.future;
  }
}

void main() {
  test(
    'web request batches, deduplicates and caches positional icons',
    () async {
      final dio = Dio();
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final titles = (options.data as Map)['titles'] as List;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'icons': [for (final _ in titles) 'code'],
                },
              ),
            );
          },
        ),
      );
      final repository = TaskIconRepositoryImpl(dio);
      final titles = [for (var i = 0; i < 31; i++) 'Задача $i'];
      final icons = await repository.getIcons([...titles, titles.first, '']);
      expect(requests, hasLength(2));
      expect(requests.first.path, 'ai/assistant/task-icons');
      expect((requests.first.data as Map)['titles'], hasLength(30));
      expect(icons, hasLength(31));
      expect(icons.values, everyElement('code'));
      await repository.getIcons(titles);
      expect(requests, hasLength(2));
      dio.close();
    },
  );

  test(
    'title cap and invalid or missing icon values use task fallback',
    () async {
      final dio = Dio();
      List<dynamic>? sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = (options.data as Map)['titles'] as List;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'icons': [null],
                },
              ),
            );
          },
        ),
      );
      final result = await TaskIconRepositoryImpl(
        dio,
      ).getIcons(['x' * 600, 'short']);
      expect(sent!.every((title) => (title as String).length <= 500), isTrue);
      expect(result.values, everyElement('task'));
      dio.close();
    },
  );

  test(
    'items appear before icons, duplicate refresh shares the pending request',
    () async {
      final icons = IconsRepository();
      final cubit = PlannerCubit(Items(), iconRepository: icons);
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state.status, PlannerStatus.success);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.iconsLoading, isTrue);
      await cubit.refresh();
      expect(icons.calls, 1);
      icons.pending.complete({'Код': 'code'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.taskIcons['Код'], 'code');
      expect(cubit.state.iconsLoading, isFalse);
      await cubit.refresh();
      expect(icons.calls, 1);
    },
  );

  test('icon service failure leaves planning successful', () async {
    final icons = IconsRepository();
    final cubit = PlannerCubit(Items(), iconRepository: icons);
    addTearDown(cubit.close);
    await cubit.refresh();
    icons.pending.completeError(Exception('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.status, PlannerStatus.success);
    expect(cubit.state.iconsLoading, isFalse);
    expect(cubit.state.actionError, isNull);
  });

  test(
    'late icons cannot attach to a renamed task or emit after close',
    () async {
      final items = Items();
      final icons = IconsRepository();
      final cubit = PlannerCubit(items, iconRepository: icons);
      await cubit.refresh();
      items.items = [
        const PlannerItemModel(id: 'one', title: 'Дом', icon: 'home'),
      ];
      await cubit.refresh();
      icons.pending.complete({'Код': 'code'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.taskIcons, isEmpty);
      expect(cubit.state.items.single.icon, 'home');
      await cubit.close();
      final secondIcons = IconsRepository();
      final second = PlannerCubit(Items(), iconRepository: secondIcons);
      await second.refresh();
      await second.close();
      secondIcons.pending.complete({'Код': 'code'});
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('explicit API icon survives parsing, copying and JSON round trip', () {
    final item = PlannerItemModel.fromJson(const {
      'id': 'one',
      'title': 'Код',
      'icon': ' document ',
    });
    expect(item.icon, 'document');
    expect(PlannerItemModel.fromJson(item.toJson()).icon, 'document');
    expect(item.copyWith(title: 'Новое').icon, 'document');
    expect(item.copyWith(icon: null).icon, isNull);
  });

  testWidgets(
    'server icon overrides automatic icon, unknown names remain safe',
    (tester) async {
      final cubit = PlannerCubit(Items());
      addTearDown(cubit.close);
      cubit.emit(const PlannerState(taskIcons: {'Код': 'code'}));
      Future<void> show(PlannerItemModel item) => tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(body: PlannerTaskSymbol(item: item, busy: false)),
          ),
        ),
      );
      await show(const PlannerItemModel(id: 'one', title: 'Код'));
      expect(find.byIcon(LucideIcons.code), findsOneWidget);
      await show(const PlannerItemModel(id: 'one', title: 'Код', icon: 'home'));
      expect(find.byIcon(LucideIcons.house), findsOneWidget);
      await show(
        const PlannerItemModel(id: 'one', title: 'Код', icon: 'unknown'),
      );
      expect(find.byIcon(LucideIcons.listTodo), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

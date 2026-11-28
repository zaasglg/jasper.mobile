import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import '../../features/planner/planner_test_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/planner/domain/repositories/planner_week_order_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_week_order_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => sl.reset());

  test(
    'startup resolves weekly planner storage and persists its order',
    () async {
      await initServiceLocator();
      final repository = sl<PlannerWeekOrderRepository>();
      final cubit = sl<PlannerWeekOrderCubit>();
      addTearDown(cubit.close);

      await repository.save('test-week-scope', {
        '2026-11-26': ['entry-2', 'entry-1'],
      });
      expect(await repository.load('test-week-scope'), {
        '2026-11-26': ['entry-2', 'entry-1'],
      });
      expect(
        sl<SharedPreferences>(),
        same(await SharedPreferences.getInstance()),
      );
    },
  );
  for (final missingPreferences in [false, true]) {
    testWidgets(
      'planner opens with production DI (missing preferences: $missingPreferences)',
      (tester) async {
        await tester.runAsync(initServiceLocator);
        if (missingPreferences) await sl.unregister<SharedPreferences>();
        final dio = sl<Dio>();
        dio.interceptors.clear();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.path == 'project-planner/account'
                      ? <dynamic>[]
                      : <String, dynamic>{},
                ),
              );
            },
          ),
        );
        await tester.pumpWidget(
          PlannerTestApp(
            child: BlocProvider(
              create: (_) => sl<PlannerCubit>(),
              child: const MaterialApp(home: PlannerScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ежедневник'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

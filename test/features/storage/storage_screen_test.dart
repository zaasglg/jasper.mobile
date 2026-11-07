import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/storage/data/storage_repository_impl.dart';
import 'package:jospar/features/storage/domain/storage_repository.dart';
import 'package:jospar/features/storage/presentation/storage_screen.dart';
import 'storage_test.dart' show Adapter, project;

void main() {
  testWidgets('tabs, search and view mode operate on loaded project files', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    final adapter = Adapter((r) {
      if (r.path == 'users/me') return {'id': 'u'};
      if (r.queryParameters['archived'] == 'true') return [];
      return [
        {
          'id': 'task',
          'detail': {
            'files': [
              {'id': 'a', 'name': 'Школа.png', 'size': 1000},
              {'id': 'b', 'name': 'Смета.pdf', 'size': 3000},
            ],
            'description': 'https://example.com',
          },
        },
      ];
    });
    sl.registerSingleton<StorageRepository>(
      StorageRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const FlutterSecureStorage(),
      ),
    );
    addTearDown(() => sl.reset());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFF715BE8)),
        home: const StorageScreen(scope: project),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Школа.png'), findsOneWidget);
    expect(find.text('Смета.pdf'), findsNothing);
    await tester.tap(find.text('Документы'));
    await tester.pumpAndSettle();
    expect(find.text('Смета.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Списком'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'нет такого файла');
    await tester.pumpAndSettle();
    expect(find.text('Здесь пока нет файлов'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

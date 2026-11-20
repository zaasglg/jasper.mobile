import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/storage/domain/entities/storage_item.dart';
import 'package:jospar/features/storage/domain/entities/storage_enums.dart';
import 'package:jospar/features/storage/data/storage_repository_impl.dart';
import 'package:jospar/features/storage/domain/storage_repository.dart';
import 'package:jospar/features/storage/presentation/storage_file_screen.dart';
import 'storage_test.dart' show project;

void main() {
  setUp(
    () => sl.registerSingleton<StorageRepository>(
      StorageRepositoryImpl(Dio(), const FlutterSecureStorage()),
    ),
  );
  tearDown(() => sl.reset());
  testWidgets('image preview supports zoom and saving', (tester) async {
    final file = StorageItem(
      id: 'f',
      name: 'cover.png',
      kind: StorageFileKind.image,
      date: DateTime(2026),
      dataUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StorageFileScreen(scope: project, item: file),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Сохранить на устройство'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'PDF uses embedded viewer and exposes fallback when document cannot render',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.PdfxApi.openDocumentData',
        (_) async => const StandardMessageCodec().encodeMessage({
          'error': {
            'code': 'invalid-pdf',
            'message': 'Invalid PDF',
            'details': null,
          },
        }),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('io.scer.pdf_renderer'),
        (_) async => throw PlatformException(code: 'invalid-pdf'),
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.PdfxApi.openDocumentData',
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('io.scer.pdf_renderer'),
          null,
        );
      });
      final file = StorageItem(
        id: 'f',
        name: 'test.pdf',
        kind: StorageFileKind.pdf,
        date: DateTime(2026),
        dataUrl: 'data:application/pdf;base64,JVBERg==',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StorageFileScreen(scope: project, item: file),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PdfViewPinch), findsOneWidget);
      expect(find.text('Не удалось отобразить PDF'), findsOneWidget);
      expect(find.text('Открыть другим приложением'), findsOneWidget);
      expect(find.text('Сохранить на устройство'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

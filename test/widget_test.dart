import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/main.dart';

void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    if (!sl.isRegistered<FlutterSecureStorage>()) {
      await initServiceLocator();
    }
  });

  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('С возвращением'), findsOneWidget);
  });
}

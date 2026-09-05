import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/presentation/screens/chat_screen.dart';

void main() {
  testWidgets('renders messenger scaffold and switches empty filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    expect(find.text('Мессенджер'), findsOneWidget);
    expect(find.byKey(const Key('messenger-search')), findsOneWidget);
    expect(find.text('Диалогов пока нет'), findsOneWidget);

    await tester.tap(find.byKey(const Key('messenger-filter-unread')));
    await tester.pumpAndSettle();

    expect(find.text('Всё прочитано'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

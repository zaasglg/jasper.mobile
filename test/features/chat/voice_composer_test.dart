import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/presentation/widgets/voice_composer.dart';

class _Recorder implements VoiceRecorder {
  bool permission = true;
  bool cancelled = false;
  String? path;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async {}
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  Widget screen(
    _Recorder recorder, {
    Future<bool> Function(String, int)? send,
  }) => MaterialApp(
    home: Scaffold(
      body: VoiceComposer(
        textField: const TextField(),
        hasText: false,
        isSending: false,
        onTextSend: () {},
        onVoiceSend: send ?? (_, _) async => true,
        recorder: recorder,
      ),
    ),
  );

  testWidgets('microphone permission denial leaves composer usable', (
    tester,
  ) async {
    final recorder = _Recorder()..permission = false;
    await tester.pumpWidget(screen(recorder));
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pumpAndSettle();
    expect(
      find.text('Разрешите доступ к микрофону в настройках приложения.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('voice-record')), findsOneWidget);
  });
  testWidgets('recording shows timer and can be discarded without sending', (
    tester,
  ) async {
    final recorder = _Recorder();
    var sent = false;
    await tester.pumpWidget(
      screen(
        recorder,
        send: (_, _) async {
          sent = true;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();
    expect(find.byKey(const Key('voice-send')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
    expect(recorder.cancelled, isTrue);
    expect(sent, isFalse);
    expect(find.byKey(const Key('voice-record')), findsOneWidget);
  });
  testWidgets('holding and sliding left cancels, sliding up locks recording', (
    tester,
  ) async {
    final recorder = _Recorder();
    await tester.pumpWidget(screen(recorder));
    var gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('voice-record'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byKey(const Key('voice-send')), findsOneWidget);
    await gesture.moveBy(const Offset(-100, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(recorder.cancelled, isTrue);
    gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('voice-record'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await gesture.up();
    await tester.pump();
    expect(find.text('Идёт запись…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'failed send preserves voice draft and successful retry deletes it',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('voice-test');
      final file = File('${directory.path}/recording.m4a')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final recorder = _Recorder()..path = file.path;
      var attempts = 0;
      await tester.pumpWidget(
        screen(
          recorder,
          send: (path, seconds) async {
            expect(path, file.path);
            expect(seconds, greaterThanOrEqualTo(1));
            return ++attempts > 1;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('voice-record')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.tap(find.byKey(const Key('voice-send')));
      await tester.pumpAndSettle();
      expect(find.text('Запись готова'), findsOneWidget);
      expect(file.existsSync(), isTrue);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('voice-send')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(file.existsSync(), isFalse);
      expect(find.byKey(const Key('voice-record')), findsOneWidget);
    },
  );
}

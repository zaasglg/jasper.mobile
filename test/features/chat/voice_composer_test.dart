import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/presentation/widgets/voice_composer.dart';

class _Recorder implements VoiceRecorder {
  bool permission = true;
  bool cancelled = false;
  String? path;
  Future<void>? startGate;
  Future<bool>? permissionGate;
  int startCalls = 0;
  int stopCalls = 0;
  @override
  Future<bool> hasPermission() async => permissionGate ?? permission;
  @override
  Future<void> start() async {
    startCalls++;
    await startGate;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    return path;
  }

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

  testWidgets('backgrounding while permission is pending cancels startup', (
    tester,
  ) async {
    final permission = Completer<bool>();
    final recorder = _Recorder()..permissionGate = permission.future;
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(screen(recorder));
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    permission.complete(true);
    await tester.pump();
    expect(recorder.startCalls, 0);
    expect(find.byKey(const Key('voice-record')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();
    expect(recorder.startCalls, 1);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('permission dialog inactivity allows foreground startup', (
    tester,
  ) async {
    final permission = Completer<bool>();
    final recorder = _Recorder()..permissionGate = permission.future;
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(screen(recorder));
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    permission.complete(true);
    await tester.pump();
    expect(recorder.startCalls, 1);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('backgrounding during recorder startup stops without sending', (
    tester,
  ) async {
    final started = Completer<void>();
    final recorder = _Recorder()..startGate = started.future;
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    started.complete();
    await tester.pump();
    expect(recorder.stopCalls, 1);
    expect(sent, isFalse);
    expect(find.byKey(const Key('voice-record')), findsOneWidget);
  });

  testWidgets('backgrounding retains a recorded draft without sending', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('voice-background');
    final file = File('${directory.path}/recording.m4a')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final recorder = _Recorder()..path = file.path;
    var sent = false;
    await tester.pumpWidget(
      screen(
        recorder,
        send: (_, _) async {
          sent = true;
          return false;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(recorder.stopCalls, 1);
    expect(find.text('Запись готова'), findsOneWidget);
    expect(file.existsSync(), isTrue);
    expect(sent, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('transient inactive state does not truncate recording', (
    tester,
  ) async {
    final recorder = _Recorder();
    await tester.pumpWidget(screen(recorder));
    await tester.tap(find.byKey(const Key('voice-record')));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(recorder.stopCalls, 0);
    expect(find.text('Идёт запись…'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const Key('voice-cancel')));
    await tester.pumpAndSettle();
  });

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
  for (final result in ['success', 'failure', 'exception']) {
    testWidgets(
      'leaving chat retains upload file until send completes ($result)',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'voice-in-flight',
        );
        final file = File('${directory.path}/recording.m4a')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() {
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        });
        final upload = Completer<bool>();
        final entered = Completer<void>();
        await tester.pumpWidget(
          screen(
            _Recorder()..path = file.path,
            send: (_, _) {
              entered.complete();
              return upload.future;
            },
          ),
        );
        await tester.tap(find.byKey(const Key('voice-record')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)),
        );
        await tester.tap(find.byKey(const Key('voice-send')));
        await tester.pump();
        expect(entered.isCompleted, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(await file.readAsBytes(), [1, 2, 3]);
        });
        if (result == 'exception') {
          upload.completeError(StateError('Upload interrupted'));
        } else {
          upload.complete(result == 'success');
        }
        await tester.pump();
        await tester.runAsync(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (await file.exists()) {
            await tester.pump();
            if (DateTime.now().isAfter(deadline)) {
              fail('Detached voice draft was not cleaned up after upload');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      final firstAttempt = Completer<void>();
      final retryAttempt = Completer<void>();
      await tester.pumpWidget(
        screen(
          recorder,
          send: (path, seconds) async {
            expect(path, file.path);
            expect(seconds, greaterThanOrEqualTo(1));
            attempts++;
            if (attempts == 1) {
              firstAttempt.complete();
              return false;
            }
            retryAttempt.complete();
            return true;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('voice-record')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      // Keep file I/O outside the widget test's fake async zone. Otherwise
      // pumpAndSettle can exhaust virtual time while a real I/O future waits.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('voice-send')));
        await tester.pump();
        await firstAttempt.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(find.text('Запись готова'), findsOneWidget);
      expect(file.existsSync(), isTrue);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('voice-send')));
        await tester.pump();
        await retryAttempt.future.timeout(const Duration(seconds: 5));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (await file.exists()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Successfully sent voice draft was not deleted');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(file.existsSync(), isFalse);
      expect(find.byKey(const Key('voice-record')), findsOneWidget);
    },
  );
}

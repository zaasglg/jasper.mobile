import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/presentation/widgets/voice_message.dart';

class _Player implements VoicePlayback {
  bool disposed = false, fail = false;
  int plays = 0;
  String? url;
  Completer<void>? setup;
  @override
  bool get playing => false;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Duration? get duration => const Duration(seconds: 7);
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Future<void> setUrl(String value) async {
    url = value;
    if (setup != null) await setup!.future;
  }

  @override
  Future<void> setFilePath(String path) async {}
  @override
  Future<void> play() async {
    plays++;
    if (fail) throw StateError('Expired source');
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

ChatMessageModel _message(String url) => ChatMessageModel.fromJson({
  'id': 'voice',
  'threadId': 'chat',
  'kind': 'AUDIO',
  'transcript': url,
  'duration': 7,
});

void main() {
  Widget screen(String url, VoicePlayback Function() factory) => MaterialApp(
    home: Scaffold(
      body: VoiceMessage(message: _message(url), playerFactory: factory),
    ),
  );

  testWidgets(
    'play failure disposes player and next tap initializes a fresh source',
    (tester) async {
      final first = _Player()..fail = true;
      final second = _Player();
      var calls = 0;
      await tester.pumpWidget(
        screen(
          'https://media.example/voice.m4a',
          () => calls++ == 0 ? first : second,
        ),
      );
      await tester.tap(find.byKey(const Key('voice-play-voice')));
      await tester.pumpAndSettle();
      expect(first.disposed, isTrue);
      await tester.tap(find.byKey(const Key('voice-play-voice')));
      await tester.pumpAndSettle();
      expect(second.url, 'https://media.example/voice.m4a');
      expect(second.plays, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed transcript resets player and ignores pending old source',
    (tester) async {
      final gate = Completer<void>();
      final first = _Player()..setup = gate;
      final second = _Player();
      var calls = 0;
      VoicePlayback factory() => calls++ == 0 ? first : second;
      await tester.pumpWidget(screen('https://media.example/old.m4a', factory));
      await tester.tap(find.byKey(const Key('voice-play-voice')));
      await tester.pump();
      await tester.pumpWidget(screen('https://media.example/new.m4a', factory));
      await tester.tap(find.byKey(const Key('voice-play-voice')));
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(first.disposed, isTrue);
      expect(first.plays, 0);
      expect(second.url, 'https://media.example/new.m4a');
      expect(second.plays, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

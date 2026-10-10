import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../domain/services/assistant_voice.dart';

class DeviceAssistantVoice
    with WidgetsBindingObserver
    implements AssistantVoice {
  DeviceAssistantVoice() {
    WidgetsBinding.instance.addObserver(this);
  }
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final _events = StreamController<VoiceEvent>.broadcast();
  Future<bool>? _initialization;
  VoiceMode _mode = VoiceMode.dictation;
  bool _listening = false;
  int _generation = 0;
  int _speechPlaybackGeneration = 0;
  Timer? _timeout;
  @override
  Stream<VoiceEvent> get events => _events.stream;
  @override
  bool get isListening => _listening;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive && _listening)) {
      unawaited(stop());
      unawaited(stopSpeaking());
    }
  }

  void _emit(VoiceEventKind kind, {String text = ''}) =>
      _events.add(VoiceEvent(kind, _mode, text: text));
  Future<bool> _initialize() => _initialization ??= _speech.initialize(
    onStatus: (status) {
      if ((status == 'done' || status == 'notListening') && _listening) {
        _listening = false;
        _timeout?.cancel();
        _emit(VoiceEventKind.stopped);
      }
    },
    onError: (error) {
      if (!_listening) return;
      _listening = false;
      _timeout?.cancel();
      _emit(
        VoiceEventKind.error,
        text: error.errorMsg.contains('permission')
            ? 'Разрешите микрофон и распознавание речи в настройках.'
            : 'Не удалось распознать речь. Нажмите микрофон и повторите.',
      );
    },
    options: [SpeechToText.androidNoBluetooth],
  );
  @override
  Future<void> listen(VoiceMode mode) async {
    await stop();
    await stopSpeaking();
    final generation = ++_generation;
    _mode = mode;
    try {
      final available = await _initialize();
      if (generation != _generation ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        return;
      }
      if (!available) {
        _initialization = null;
        throw const VoiceException(
          'Разрешите микрофон и распознавание речи в настройках телефона.',
        );
      }
      final locales = await _speech.locales();
      if (generation != _generation) return;
      final russian = locales
          .where((e) => e.localeId.toLowerCase().startsWith('ru'))
          .firstOrNull;
      _listening = true;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: russian?.localeId,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 8),
          partialResults: true,
          cancelOnError: true,
          onDevice: mode == VoiceMode.wake,
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          if (generation != _generation) return;
          _emit(
            result.finalResult
                ? VoiceEventKind.finalResult
                : VoiceEventKind.partial,
            text: result.recognizedWords,
          );
        },
      );
      if (generation != _generation) return;
      if (!_listening) return;
      _emit(VoiceEventKind.listening);
      _timeout = Timer(const Duration(seconds: 45), () => unawaited(stop()));
    } catch (error) {
      if (generation == _generation) {
        _listening = false;
        _emit(
          VoiceEventKind.error,
          text: error is VoiceException
              ? error.message
              : 'Голосовой ввод недоступен на этом устройстве.',
        );
      }
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _timeout?.cancel();
    final wasListening = _listening;
    _listening = false;
    try {
      await _speech.cancel();
    } catch (_) {
      /* Recognition may not be initialized yet. */
    }
    if (wasListening) _emit(VoiceEventKind.stopped);
  }

  @override
  Future<void> speak(String text) async {
    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await stop();
    final generation = ++_speechPlaybackGeneration;
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.48);
      if (generation != _speechPlaybackGeneration ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      await _tts.speak(text.replaceAll(RegExp(r'[*#`_]'), ''), focus: true);
    } catch (_) {
      /* The written answer stays available if speech is unavailable. */
    }
  }

  @override
  Future<void> stopSpeaking() async {
    ++_speechPlaybackGeneration;
    try {
      await _tts.stop();
    } catch (_) {
      /* Unsupported platforms retain text input. */
    }
  }
}

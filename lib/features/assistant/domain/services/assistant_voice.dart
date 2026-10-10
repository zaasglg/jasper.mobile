import 'package:equatable/equatable.dart';

enum VoiceMode { wake, dictation }

enum VoiceEventKind { listening, partial, finalResult, stopped, error }

class VoiceEvent extends Equatable {
  const VoiceEvent(this.kind, this.mode, {this.text = ''});
  final VoiceEventKind kind;
  final VoiceMode mode;
  final String text;
  @override
  List<Object?> get props => [kind, mode, text];
}

abstract interface class AssistantVoice {
  Stream<VoiceEvent> get events;
  bool get isListening;
  Future<void> listen(VoiceMode mode);
  Future<void> stop();
  Future<void> speak(String text);
  Future<void> stopSpeaking();
}

class VoiceException implements Exception {
  const VoiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

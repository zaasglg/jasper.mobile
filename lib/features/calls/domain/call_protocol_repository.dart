import 'package:equatable/equatable.dart';
import 'entities/call_room.dart';

class CallProtocolEntry extends Equatable {
  const CallProtocolEntry({
    required this.id,
    required this.userId,
    required this.text,
    required this.timestamp,
    this.kind = 'chat',
    this.isKeyDecision = false,
  });
  final String id, userId, text, timestamp, kind;
  final bool isKeyDecision;
  factory CallProtocolEntry.fromJson(Map<String, dynamic> json) =>
      CallProtocolEntry(
        id: json['id'] is String ? json['id'] as String : '',
        userId: json['userId'] is String ? json['userId'] as String : '',
        text: json['text'] is String ? json['text'] as String : '',
        timestamp: json['timestamp'] is String
            ? json['timestamp'] as String
            : '',
        kind: json['kind'] == 'speech' ? 'speech' : 'chat',
        isKeyDecision: json['isKeyDecision'] == true,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'text': text,
    'timestamp': timestamp,
    'kind': kind,
    'isKeyDecision': isKeyDecision,
  };
  CallProtocolEntry copyWith({bool? isKeyDecision}) => CallProtocolEntry(
    id: id,
    userId: userId,
    text: text,
    timestamp: timestamp,
    kind: kind,
    isKeyDecision: isKeyDecision ?? this.isKeyDecision,
  );
  @override
  List<Object?> get props => [id, userId, text, timestamp, kind, isKeyDecision];
}

abstract interface class CallProtocolRepository {
  Future<Map<String, dynamic>> access(CallRoom room);
  Future<Map<String, dynamic>> grant(
    CallRoom room,
    String userId,
    bool enabled,
  );
  Future<Map<String, dynamic>> versions(CallRoom room, int skip);
  Future<Map<String, dynamic>> version(CallRoom room, String id);
  Future<Map<String, dynamic>> save(
    CallRoom room,
    Map<String, dynamic> content,
  );
}

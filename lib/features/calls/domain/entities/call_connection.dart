import 'package:equatable/equatable.dart';
import 'call_room.dart';

class CallConnection extends Equatable {
  const CallConnection({required this.token, required this.url, this.room});
  final String token, url;
  final CallRoom? room;
  CallConnection copyWith({String? token, String? url, CallRoom? room}) =>
      CallConnection(
        token: token ?? this.token,
        url: url ?? this.url,
        room: room ?? this.room,
      );
  @override
  List<Object?> get props => [token, url, room];
}

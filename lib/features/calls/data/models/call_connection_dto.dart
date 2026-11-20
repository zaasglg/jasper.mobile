import 'package:equatable/equatable.dart';
import '../../domain/entities/call_connection.dart';
import 'call_room_dto.dart';

class CallConnectionDto extends Equatable {
  const CallConnectionDto({required this.token, required this.url, this.room});
  final String token, url;
  final CallRoomDto? room;
  factory CallConnectionDto.fromJson(Map<String, dynamic> json) =>
      CallConnectionDto(
        token: json['token']?.toString() ?? '',
        url: json['wsUrl']?.toString() ?? '',
        room: json['room'] is Map
            ? CallRoomDto.fromJson(
                Map<String, dynamic>.from(json['room'] as Map),
              )
            : null,
      );
  Map<String, dynamic> toJson() => {
    'token': token,
    'wsUrl': url,
    if (room != null) 'room': room!.toJson(),
  };
  CallConnectionDto copyWith({String? token, String? url, CallRoomDto? room}) =>
      CallConnectionDto(
        token: token ?? this.token,
        url: url ?? this.url,
        room: room ?? this.room,
      );
  factory CallConnectionDto.fromEntity(CallConnection entity) =>
      CallConnectionDto(
        token: entity.token,
        url: entity.url,
        room: entity.room == null ? null : CallRoomDto.fromEntity(entity.room!),
      );
  CallConnection toEntity() =>
      CallConnection(token: token, url: url, room: room?.toEntity());
  @override
  List<Object?> get props => [token, url, room];
}

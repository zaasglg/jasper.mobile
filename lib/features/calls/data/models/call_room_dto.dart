import 'package:equatable/equatable.dart';
import '../../domain/entities/call_room.dart';
import '../../../../core/network/api_constants.dart';

class CallRoomDto extends Equatable {
  const CallRoomDto({
    required this.id,
    required this.workspaceId,
    this.mode = 'audio',
    this.title = '',
    this.callerName = '',
    this.callerAvatar,
    this.callerId = '',
    this.threadId = '',
    this.status = 'active',
    this.createdById = '',
    this.endOnHangup = false,
    this.canInvite = false,
  });
  final String id,
      workspaceId,
      mode,
      title,
      callerName,
      callerId,
      threadId,
      status,
      createdById;
  final String? callerAvatar;
  final bool endOnHangup, canInvite;
  static String? _resolveAvatar(String? value) {
    final source = value?.trim();
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) return source;
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final resolved = ApiConstants.origin.resolveUri(uri);
    return ['https', 'http'].contains(resolved.scheme)
        ? resolved.toString()
        : null;
  }

  factory CallRoomDto.fromJson(Map<String, dynamic> json) {
    final caller = json['createdBy'] is Map
        ? json['createdBy'] as Map
        : const {};
    return CallRoomDto(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString() ?? '',
      mode: json['mode'] == 'video' ? 'video' : 'audio',
      title: json['title']?.toString() ?? '',
      callerName:
          caller['name']?.toString() ?? json['callerName']?.toString() ?? '',
      callerId: caller['id']?.toString() ?? json['callerId']?.toString() ?? '',
      callerAvatar: _resolveAvatar(
        caller['avatarUrl']?.toString() ?? json['callerAvatar']?.toString(),
      ),
      threadId: json['threadId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdById: json['createdById']?.toString() ?? '',
      endOnHangup: json['endOnHangup'] == true,
      canInvite: json['canInvite'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'mode': mode,
    'title': title,
    'callerName': callerName,
    'callerId': callerId,
    'callerAvatar': callerAvatar,
    'threadId': threadId,
    'status': status,
    'createdById': createdById,
    'endOnHangup': endOnHangup,
    'canInvite': canInvite,
  };
  CallRoomDto copyWith({
    String? id,
    String? workspaceId,
    String? mode,
    String? title,
    String? callerName,
    String? callerId,
    String? callerAvatar,
    String? threadId,
    String? status,
    String? createdById,
    bool? endOnHangup,
    bool? canInvite,
  }) => CallRoomDto(
    id: id ?? this.id,
    workspaceId: workspaceId ?? this.workspaceId,
    mode: mode ?? this.mode,
    title: title ?? this.title,
    callerName: callerName ?? this.callerName,
    callerId: callerId ?? this.callerId,
    callerAvatar: callerAvatar ?? this.callerAvatar,
    threadId: threadId ?? this.threadId,
    status: status ?? this.status,
    createdById: createdById ?? this.createdById,
    endOnHangup: endOnHangup ?? this.endOnHangup,
    canInvite: canInvite ?? this.canInvite,
  );
  factory CallRoomDto.fromEntity(CallRoom entity) => CallRoomDto(
    id: entity.id,
    workspaceId: entity.workspaceId,
    mode: entity.mode,
    title: entity.title,
    callerName: entity.callerName,
    callerId: entity.callerId,
    callerAvatar: entity.callerAvatar,
    threadId: entity.threadId,
    status: entity.status,
    createdById: entity.createdById,
    endOnHangup: entity.endOnHangup,
    canInvite: entity.canInvite,
  );
  CallRoom toEntity() => CallRoom(
    id: id,
    workspaceId: workspaceId,
    mode: mode,
    title: title,
    callerName: callerName,
    callerId: callerId,
    callerAvatar: callerAvatar,
    threadId: threadId,
    status: status,
    createdById: createdById,
    endOnHangup: endOnHangup,
    canInvite: canInvite,
  );
  @override
  List<Object?> get props => [
    id,
    workspaceId,
    mode,
    title,
    callerName,
    callerId,
    callerAvatar,
    threadId,
    status,
    createdById,
    endOnHangup,
    canInvite,
  ];
}

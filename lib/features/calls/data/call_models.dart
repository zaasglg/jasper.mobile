import 'package:equatable/equatable.dart';

class CallRoom extends Equatable {
  const CallRoom({
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
  bool get video => mode == 'video';
  factory CallRoom.fromJson(Map<String, dynamic> json) {
    final caller = json['createdBy'] is Map
        ? json['createdBy'] as Map
        : const {};
    return CallRoom(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString() ?? '',
      mode: json['mode'] == 'video' ? 'video' : 'audio',
      title: json['title']?.toString() ?? '',
      callerName:
          caller['name']?.toString() ?? json['callerName']?.toString() ?? '',
      callerId: caller['id']?.toString() ?? json['callerId']?.toString() ?? '',
      callerAvatar:
          caller['avatarUrl']?.toString() ?? json['callerAvatar']?.toString(),
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
  CallRoom copyWith({
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
  }) => CallRoom(
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

class CallConnection extends Equatable {
  const CallConnection({required this.token, required this.url, this.room});
  final String token, url;
  final CallRoom? room;
  factory CallConnection.fromJson(Map<String, dynamic> json) => CallConnection(
    token: json['token']?.toString() ?? '',
    url: json['wsUrl']?.toString() ?? '',
    room: json['room'] is Map
        ? CallRoom.fromJson(Map<String, dynamic>.from(json['room'] as Map))
        : null,
  );
  Map<String, dynamic> toJson() => {
    'token': token,
    'wsUrl': url,
    if (room != null) 'room': room!.toJson(),
  };
  CallConnection copyWith({String? token, String? url, CallRoom? room}) =>
      CallConnection(
        token: token ?? this.token,
        url: url ?? this.url,
        room: room ?? this.room,
      );
  @override
  List<Object?> get props => [token, url, room];
}

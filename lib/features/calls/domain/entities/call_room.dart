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

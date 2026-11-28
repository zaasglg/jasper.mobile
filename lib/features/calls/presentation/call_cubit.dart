import 'protocol/call_protocol_cubit.dart';
import '../data/call_message_changes.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/call_room.dart';
import '../domain/call_repository.dart';
import '../domain/call_media.dart';

enum CallPhase { idle, preparing, connecting, active, ending, ended, failed }

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.room,
    this.incoming,
    this.error,
    this.creator = false,
    this.controlsBusy = false,
    this.speaker = false,
    this.revision = 0,
    this.startedAt,
  });
  final CallPhase phase;
  final CallRoom? room, incoming;
  final String? error;
  final bool creator, controlsBusy, speaker;
  final int revision;
  final DateTime? startedAt;
  bool get busy => [
    CallPhase.preparing,
    CallPhase.connecting,
    CallPhase.active,
    CallPhase.ending,
  ].contains(phase);
  CallState copyWith({
    CallPhase? phase,
    CallRoom? room,
    CallRoom? incoming,
    bool clearIncoming = false,
    String? error,
    bool clearError = false,
    bool? creator,
    bool? controlsBusy,
    bool? speaker,
    int? revision,
    DateTime? startedAt,
  }) => CallState(
    phase: phase ?? this.phase,
    room: room ?? this.room,
    incoming: clearIncoming ? null : incoming ?? this.incoming,
    error: clearError ? null : error ?? this.error,
    creator: creator ?? this.creator,
    controlsBusy: controlsBusy ?? this.controlsBusy,
    speaker: speaker ?? this.speaker,
    revision: revision ?? this.revision,
    startedAt: startedAt ?? this.startedAt,
  );
  @override
  List<Object?> get props => [
    phase,
    room,
    incoming,
    error,
    creator,
    controlsBusy,
    speaker,
    revision,
    startedAt,
  ];
}

class CallCubit extends Cubit<CallState> {
  CallCubit(this.repository, this.media, {this.protocol})
    : super(const CallState()) {
    media.addListener(_onMedia);
  }
  final CallProtocolCubit? protocol;
  final CallRepository repository;
  final CallMedia media;
  bool _polling = false;
  bool _starting = false;
  bool _controlling = false;
  int _generation = 0;
  final Set<String> _dismissed = {};
  String _error(Object e) => e is CallException
      ? e.message
      : 'Не удалось подключиться к звонку. Проверьте интернет и разрешения.';
  void _onMedia() {
    if (isClosed) return;
    if (media.ended && state.busy && state.phase != CallPhase.ending) {
      finish(remote: true);
      return;
    }
    emit(state.copyWith(revision: state.revision + 1));
  }

  Future<bool> start({
    required String workspaceId,
    required List<String> invitees,
    required bool video,
    required String threadId,
    required String title,
  }) async {
    if (_starting || _controlling || state.busy || state.incoming != null) {
      return false;
    }
    protocol?.clear();
    _starting = true;
    final generation = ++_generation;
    emit(CallState(phase: CallPhase.preparing, creator: true, speaker: video));
    CallRoom? created;
    try {
      await media.prepare(video);
      if (generation != _generation) {
        await media.disconnect();
        return false;
      }
      final connection = await repository.create(
        workspaceId: workspaceId,
        invitees: invitees,
        video: video,
        threadId: threadId,
        title: title,
      );
      created = connection.room;
      notifyCallMessageChanges();
      if (created == null || created.id.isEmpty) {
        throw const CallException('Сервер не вернул комнату звонка.');
      }
      if (generation != _generation) {
        await repository.end(created);
        await media.disconnect();
        return false;
      }
      emit(
        state.copyWith(
          phase: CallPhase.connecting,
          room: created.copyWith(title: title),
          clearIncoming: true,
        ),
      );
      await media.connect(connection);
      if (generation != _generation) {
        await media.disconnect();
        return false;
      }
      await media.setSpeaker(video);
      final startedAt = DateTime.now();
      emit(state.copyWith(phase: CallPhase.active, startedAt: startedAt));
      if (state.room case final room?) protocol?.begin(room, startedAt);
      return true;
    } catch (e) {
      await media.disconnect();
      if (created != null) {
        try {
          await repository.end(created);
        } catch (_) {}
      }
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(phase: CallPhase.failed, error: _error(e)));
      }
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<bool> accept(CallRoom room, {bool creator = false}) async {
    if (_starting || _controlling || state.busy) return false;
    protocol?.clear();
    _starting = true;
    final generation = ++_generation;
    emit(
      CallState(
        phase: CallPhase.preparing,
        room: room,
        speaker: room.video,
        creator: creator,
      ),
    );
    bool joined = false;
    bool endOnFailure = room.endOnHangup || creator;
    try {
      await media.prepare(room.video);
      if (generation != _generation) {
        await media.disconnect();
        return false;
      }
      final latest = await repository.state(room);
      if (generation != _generation) {
        await media.disconnect();
        return false;
      }
      if (latest.status != 'active') {
        throw const CallException('Звонок уже завершён.');
      }
      final connection = await repository.join(room);
      joined = true;
      endOnFailure = latest.endOnHangup || creator;
      if (generation != _generation) {
        if (endOnFailure) await repository.end(room);
        await media.disconnect();
        return false;
      }
      _dismissed.add(room.id);
      emit(
        state.copyWith(
          phase: CallPhase.connecting,
          room: room.copyWith(
            endOnHangup: latest.endOnHangup,
            canInvite: latest.canInvite,
            mode: latest.mode,
          ),
        ),
      );
      await media.connect(connection);
      if (generation != _generation) {
        await media.disconnect();
        return false;
      }
      await media.setSpeaker(room.video);
      final startedAt = DateTime.now();
      emit(state.copyWith(phase: CallPhase.active, startedAt: startedAt));
      if (state.room case final room?) protocol?.begin(room, startedAt);
      return true;
    } catch (e) {
      await media.disconnect();
      if (joined && endOnFailure) {
        try {
          await repository.end(room);
        } catch (_) {}
      }
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(phase: CallPhase.failed, error: _error(e)));
      }
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<void> decline(CallRoom room) async {
    if (state.controlsBusy) return;
    emit(state.copyWith(controlsBusy: true, clearError: true));
    try {
      await repository.decline(room);
      _dismissed.add(room.id);
      if (!isClosed) emit(state.copyWith(clearIncoming: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: _error(e)));
    } finally {
      if (!isClosed) emit(state.copyWith(controlsBusy: false));
    }
  }

  Future<void> poll() async {
    if (_polling || isClosed) return;
    _polling = true;
    final generation = _generation;
    try {
      if (state.room != null && state.phase == CallPhase.active) {
        final latest = await repository.state(state.room!);
        if (isClosed || generation != _generation) return;
        if (latest.status != 'active') {
          await finish(remote: true);
          return;
        }
        emit(
          state.copyWith(
            room: state.room!.copyWith(
              mode: latest.mode,
              endOnHangup: latest.endOnHangup,
              canInvite: latest.canInvite,
            ),
            revision: state.revision + 1,
          ),
        );
      } else if (!state.busy) {
        final incoming = await repository.incoming();
        if (isClosed || generation != _generation || state.busy) return;
        final next = incoming
            .where((e) => !_dismissed.contains(e.id))
            .firstOrNull;
        _dismissed.removeWhere((id) => !incoming.any((e) => e.id == id));
        emit(
          state.copyWith(
            incoming: next,
            clearIncoming: next == null,
            clearError: next != null && next.id != state.incoming?.id,
          ),
        );
      }
    } catch (_) {
      /* Polling retries without interrupting media on a transient API failure. */
    } finally {
      _polling = false;
    }
  }

  Future<void> control(String action) async {
    if (state.phase != CallPhase.active || state.controlsBusy) return;
    _controlling = true;
    final generation = _generation;
    final activeRoom = state.room!;
    emit(state.copyWith(controlsBusy: true, clearError: true));
    try {
      switch (action) {
        case 'microphone':
          await media.setMicrophone(!media.microphone);
        case 'camera':
          final enabled = !media.camera;
          await media.setCamera(enabled);
          if (generation != _generation) return;
          if (enabled && !activeRoom.video) {
            try {
              await repository.mode(activeRoom, true);
            } catch (_) {
              await media.setCamera(false);
              rethrow;
            }
            if (generation != _generation) return;
            emit(state.copyWith(room: activeRoom.copyWith(mode: 'video')));
          }
        case 'screen':
          await media.setScreenShare(!media.screenSharing);
        case 'speaker':
          await media.setSpeaker(!state.speaker);
          if (generation != _generation) return;
          emit(state.copyWith(speaker: !state.speaker));
        case 'switch':
          await media.switchCamera();
      }
    } catch (e) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(error: _error(e)));
      }
    } finally {
      _controlling = false;
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(controlsBusy: false, revision: state.revision + 1));
      }
    }
  }

  Future<void> finish({bool remote = false, bool endForAll = false}) async {
    if (state.phase == CallPhase.ending) return;
    ++_generation;
    final room = state.room;
    emit(
      state.copyWith(
        phase: CallPhase.ending,
        clearIncoming: true,
        clearError: true,
      ),
    );
    protocol?.end();
    await media.disconnect();
    String? error;
    if (!remote &&
        room != null &&
        (endForAll || state.creator || room.endOnHangup)) {
      try {
        await repository.end(room);
      } catch (e) {
        error = _error(e);
      }
    }
    notifyCallMessageChanges();
    if (!isClosed) {
      emit(
        state.copyWith(
          phase: CallPhase.ended,
          error: error,
          clearError: error == null,
          controlsBusy: false,
        ),
      );
    }
  }

  Future<void> reset() async {
    ++_generation;
    protocol?.clear();
    await media.disconnect();
    if (!isClosed) emit(const CallState());
  }

  @override
  Future<void> close() async {
    ++_generation;
    media.removeListener(_onMedia);
    await media.disconnect();
    await protocol?.close();
    media.dispose();
    return super.close();
  }
}

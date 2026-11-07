import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_models.dart';
import 'package:jospar/features/calls/data/system_incoming_calls.dart';
import 'package:jospar/features/calls/domain/call_media.dart';
import 'package:jospar/features/calls/domain/call_repository.dart';
import 'package:jospar/features/calls/presentation/call_cubit.dart';
import 'package:jospar/features/calls/presentation/system_call_controller.dart';

const room = CallRoom(
  id: 'room',
  workspaceId: 'workspace',
  callerName: 'Коллега',
);
Future<void> settle() => Future<void>.delayed(Duration.zero);
void main() {
  late _Repository repo;
  late _Media media;
  late CallCubit cubit;
  late _Native native;
  late SystemCallController controller;
  int opened = 0;
  setUp(() {
    repo = _Repository();
    media = _Media();
    native = _Native();
    opened = 0;
    cubit = CallCubit(repo, media);
    controller = SystemCallController(cubit, native, onOpen: () => opened++);
  });
  tearDown(() async {
    controller.dispose();
    await cubit.close();
  });
  Future<void> incoming() async {
    await cubit.poll();
    await settle();
  }

  test(
    'repeated polls report one OS call; remote cancellation removes it',
    () async {
      await incoming();
      await incoming();
      expect(native.shown, ['room']);
      expect(controller.presenting, isTrue);
      repo.rooms = [];
      await incoming();
      expect(native.ended, ['room']);
      expect(controller.presenting, isFalse);
    },
  );
  test(
    'native answer joins once; native end releases the active call',
    () async {
      await incoming();
      await native.event('answer');
      await native.event('answer');
      await settle();
      expect(repo.joins, 1);
      expect(opened, 1);
      expect(cubit.state.phase, CallPhase.active);
      expect(native.connectedIDs, ['room']);
      await native.event('end');
      await settle();
      expect(cubit.state.phase, CallPhase.ended);
      expect(media.microphone, isFalse);
      expect(native.ended, contains('room'));
    },
  );
  test('in-app answer requests a CallKit transaction before joining', () async {
    await incoming();
    await controller.answer(room);
    expect(native.answers, ['room']);
    expect(repo.joins, 0);
    await native.event('answer');
    await settle();
    expect(repo.joins, 1);
  });
  test('decline and timeout update the server without joining media', () async {
    await incoming();
    await native.event('timeout');
    await settle();
    expect(repo.declines, 1);
    expect(repo.joins, 0);
    expect(media.microphone, isFalse);
    await incoming();
    expect(native.shown, ['room']);
  });
  test('unknown/stale action cannot answer a different room', () async {
    await incoming();
    await native.callback('answer', 'other', false);
    expect(repo.joins, 0);
    repo.rooms = [];
    await incoming();
    await native.event('answer');
    expect(repo.joins, 0);
  });
  test(
    'failed OS answer releases native audio before in-app fallback',
    () async {
      await incoming();
      native.answerFails = true;
      await controller.answer(room);
      await settle();
      expect(native.ended, contains('room'));
      expect(controller.presenting, isFalse);
      expect(cubit.state.phase, CallPhase.active);
      expect(media.microphone, isTrue);
    },
  );
  test('unsupported OS presentation retains in-app answer', () async {
    native.available = false;
    await incoming();
    expect(controller.presenting, isFalse);
    await controller.answer(room);
    expect(cubit.state.phase, CallPhase.active);
    expect(repo.joins, 1);
  });
  test('mute from system UI is idempotent and app changes sync back', () async {
    await incoming();
    await native.event('answer');
    await settle();
    await native.callback('mute', 'room', true);
    await native.callback('mute', 'room', true);
    await settle();
    expect(media.microphone, isFalse);
    await cubit.control('microphone');
    await settle();
    expect(media.microphone, isTrue);
    expect(native.mutes.last, false);
  });
  test(
    'answer while OS presentation is pending also answers the OS call',
    () async {
      native.showGate = Completer<bool>();
      await cubit.poll();
      await settle();
      await controller.answer(room);
      native.showGate!.complete(true);
      await settle();
      await settle();
      expect(cubit.state.phase, CallPhase.active);
      expect(native.answers, ['room']);
    },
  );
  test(
    'remote cancellation during native presentation is reconciled',
    () async {
      native.showGate = Completer<bool>();
      await cubit.poll();
      await settle();
      repo.rooms = [];
      await cubit.poll();
      native.showGate!.complete(true);
      await settle();
      await settle();
      expect(native.ended, ['room']);
      expect(controller.presenting, isFalse);
    },
  );
}

class _Native extends SystemIncomingCalls {
  late Future<void> Function(String, String, bool) callback;
  final shown = <String>[],
      ended = <String>[],
      answers = <String>[],
      connectedIDs = <String>[];
  final mutes = <bool>[];
  bool available = true;
  bool answerFails = false;
  Completer<bool>? showGate;
  Future<void> event(String action) => callback(action, 'room', false);
  @override
  void listen(Future<void> Function(String, String, bool) handler) {
    callback = handler;
  }

  @override
  Future<bool> show(CallRoom room) async {
    shown.add(room.id);
    return showGate?.future ?? available;
  }

  @override
  Future<void> answer(String id) async {
    answers.add(id);
    if (answerFails) throw StateError('OS transaction rejected');
  }

  @override
  Future<void> end(String id) async {
    ended.add(id);
  }

  @override
  Future<void> connected(String id) async {
    connectedIDs.add(id);
  }

  @override
  Future<void> mute(String id, bool value) async {
    mutes.add(value);
  }

  @override
  void dispose() {}
}

class _Repository implements CallRepository {
  List<CallRoom> rooms = [room];
  int joins = 0, declines = 0;
  @override
  Future<List<CallRoom>> incoming() async => rooms;
  @override
  Future<CallRoom> state(CallRoom value) async => value;
  @override
  Future<CallConnection> join(CallRoom value) async {
    joins++;
    return const CallConnection(token: 'token', url: 'wss://test');
  }

  @override
  Future<void> decline(CallRoom value) async {
    declines++;
  }

  @override
  Future<void> end(CallRoom value) async {}
  @override
  Future<void> mode(CallRoom value, bool video) async {}
  @override
  Future<CallConnection> create({
    required String workspaceId,
    required List<String> invitees,
    required bool video,
    required String threadId,
    required String title,
  }) async =>
      const CallConnection(token: 'token', url: 'wss://test', room: room);
}

class _Media extends CallMedia {
  @override
  bool ended = false;
  @override
  bool reconnecting = false;
  @override
  bool microphone = false;
  @override
  bool camera = false;
  @override
  bool screenSharing = false;
  @override
  int remoteCount = 0;
  @override
  Future<void> prepare(bool video) async {
    microphone = true;
    camera = video;
  }

  @override
  Future<void> connect(CallConnection connection) async {}
  @override
  Future<void> disconnect() async {
    microphone = false;
    camera = false;
  }

  @override
  Future<void> setMicrophone(bool value) async {
    microphone = value;
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool value) async {
    camera = value;
  }

  @override
  Future<void> setScreenShare(bool value) async {
    screenSharing = value;
  }

  @override
  Future<void> setSpeaker(bool value) async {}
  @override
  Future<void> switchCamera() async {}
}

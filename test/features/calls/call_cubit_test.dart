import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/calls/presentation/call_screen.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_models.dart';
import 'package:jospar/features/calls/domain/call_media.dart';
import 'package:jospar/features/calls/domain/call_repository.dart';
import 'package:jospar/features/calls/presentation/call_cubit.dart';

const room = CallRoom(
  id: 'r',
  workspaceId: 'w',
  title: 'Коллега',
  threadId: 'dm:a:b',
  endOnHangup: true,
);
void main() {
  late _Repository repo;
  late _Media media;
  late CallCubit cubit;
  setUp(() {
    repo = _Repository();
    media = _Media();
    cubit = CallCubit(repo, media);
  });
  tearDown(() async {
    await cubit.close();
  });
  Future<bool> start({bool video = false}) => cubit.start(
    workspaceId: 'w',
    invitees: ['b'],
    video: video,
    threadId: 'dm:a:b',
    title: 'Коллега',
  );
  testWidgets(
    'call controls fit a narrow phone and release devices on hangup',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      sl.registerSingleton<CallCubit>(cubit);
      addTearDown(() => sl.unregister<CallCubit>());
      await start();
      await tester.pumpWidget(const MaterialApp(home: CallScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Микрофон'), findsOneWidget);
      await tester.tap(find.byTooltip('Экран'));
      await tester.pumpAndSettle();
      expect(media.screenSharing, isTrue);
      expect(find.text('Остановить экран'), findsOneWidget);
      await tester.tap(find.byTooltip('Остановить экран'));
      await tester.pumpAndSettle();
      expect(media.screenSharing, isFalse);
      await tester.tap(find.byTooltip('Микрофон'));
      await tester.pumpAndSettle();
      expect(media.microphone, isFalse);
      await tester.tap(find.byTooltip('Завершить звонок'));
      await tester.pumpAndSettle();
      expect(repo.ends, 1);
      expect(find.text('Звонок завершён'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'screen sharing starts and stops independently of camera and room mode',
    () async {
      await start(video: true);
      await cubit.control('screen');
      expect(media.screenSharing, isTrue);
      expect(media.camera, isTrue);
      expect(media.microphone, isTrue);
      expect(repo.modeChanges, isEmpty);
      await cubit.control('screen');
      expect(media.screenSharing, isFalse);
      await cubit.control('screen');
      await cubit.finish();
      expect(media.screenSharing, isFalse);
    },
  );
  test('cancelled screen consent leaves the call connected', () async {
    await start();
    media.rejectScreen = true;
    await cubit.control('screen');
    expect(media.screenSharing, isFalse);
    expect(media.microphone, isTrue);
    expect(media.disconnections, 0);
  });
  test('outgoing audio checks devices before inviting and connects', () async {
    expect(await start(), isTrue);
    expect(media.prepared, false);
    expect(media.microphone, isTrue);
    expect(media.camera, isFalse);
    expect(repo.creates, 1);
    expect(cubit.state.phase, CallPhase.active);
    expect(cubit.state.creator, isTrue);
    expect(await start(), isFalse);
    expect(repo.creates, 1);
  });
  test('video call publishes camera and selects speaker', () async {
    expect(await start(video: true), isTrue);
    expect(media.camera, isTrue);
    expect(media.speaker, isTrue);
  });
  test('permission failure does not ring the other participant', () async {
    media.permissionDenied = true;
    expect(await start(), isFalse);
    expect(repo.creates, 0);
    expect(cubit.state.phase, CallPhase.failed);
    expect(media.disconnections, greaterThan(0));
  });
  test(
    'connection failure ends newly created room and frees devices',
    () async {
      media.connectionFails = true;
      expect(await start(), isFalse);
      expect(repo.ends, 1);
      expect(media.disconnections, greaterThan(0));
    },
  );
  test(
    'accept checks room state and joins without creating a new room',
    () async {
      repo.incomingRooms = [room];
      await cubit.poll();
      expect(cubit.state.incoming, room);
      expect(await cubit.accept(room), isTrue);
      expect(repo.joins, 1);
      expect(repo.creates, 0);
      expect(cubit.state.incoming, isNull);
      await cubit.finish();
      expect(repo.ends, 1);
      expect(cubit.state.phase, CallPhase.ended);
    },
  );
  test('expired incoming call cannot be accepted', () async {
    repo.latest = room.copyWith(status: 'ended');
    expect(await cubit.accept(room), isFalse);
    expect(repo.joins, 0);
    expect(cubit.state.phase, CallPhase.failed);
  });
  test('decline uses server endpoint and suppresses stale invites', () async {
    repo.incomingRooms = [room];
    await cubit.poll();
    await cubit.decline(room);
    await cubit.poll();
    expect(repo.declines, 1);
    expect(cubit.state.incoming, isNull);
  });
  test('poll reflects remote hangup and releases microphone', () async {
    await start();
    repo.latest = room.copyWith(status: 'ended');
    await cubit.poll();
    expect(cubit.state.phase, CallPhase.ended);
    expect(repo.ends, 0);
    expect(media.microphone, isFalse);
  });
  test('group participant leaves without ending call for everyone', () async {
    repo.latest = room.copyWith(endOnHangup: false);
    await cubit.accept(room);
    await cubit.finish();
    expect(repo.ends, 0);
    expect(media.disconnections, greaterThan(0));
  });
  test(
    'turning on camera updates web room mode; rejected change rolls back camera',
    () async {
      await start();
      await cubit.control('camera');
      expect(media.camera, isTrue);
      expect(repo.modeChanges, [true]);
      expect(cubit.state.room!.video, isTrue);
      await cubit.control('microphone');
      expect(media.microphone, isFalse);
    },
  );
  test('failed mode change rolls back camera', () async {
    await start();
    repo.modeFails = true;
    await cubit.control('camera');
    expect(media.camera, isFalse);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.controlsBusy, isFalse);
  });
  test('cancel while permission dialog is open never creates a room', () async {
    final gate = Completer<void>();
    media.prepareGate = gate.future;
    final pending = start();
    await Future<void>.delayed(Duration.zero);
    await cubit.finish();
    gate.complete();
    expect(await pending, isFalse);
    expect(repo.creates, 0);
    expect(cubit.state.phase, CallPhase.ended);
    expect(media.microphone, isFalse);
  });
  test(
    'late room creation after hangup is ended rather than connected',
    () async {
      final gate = Completer<void>();
      repo.createGate = gate.future;
      final pending = start();
      await Future<void>.delayed(Duration.zero);
      await cubit.finish();
      gate.complete();
      expect(await pending, isFalse);
      expect(repo.ends, 1);
      expect(media.connects, 0);
      expect(media.microphone, isFalse);
    },
  );
  test('late camera permission cannot change an ended call', () async {
    await start();
    final gate = Completer<void>();
    media.cameraGate = gate.future;
    final pending = cubit.control('camera');
    await Future<void>.delayed(Duration.zero);
    await cubit.finish();
    gate.complete();
    await pending;
    expect(cubit.state.phase, CallPhase.ended);
    expect(cubit.state.error, isNull);
    expect(repo.modeChanges, isEmpty);
  });
  test('hangup stops capture before waiting for the server', () async {
    await start();
    final gate = Completer<void>();
    repo.endGate = gate.future;
    final pending = cubit.finish();
    await Future<void>.delayed(Duration.zero);
    expect(media.microphone, isFalse);
    expect(media.camera, isFalse);
    expect(cubit.state.phase, CallPhase.ending);
    gate.complete();
    await pending;
    expect(cubit.state.phase, CallPhase.ended);
  });
  test(
    'failed server hangup still frees local microphone and shows error',
    () async {
      await start();
      repo.endFails = true;
      await cubit.finish();
      expect(cubit.state.phase, CallPhase.ended);
      expect(media.microphone, isFalse);
      expect(cubit.state.error, isNotNull);
    },
  );
}

class _Repository implements CallRepository {
  int creates = 0, joins = 0, ends = 0, declines = 0;
  bool modeFails = false, endFails = false;
  final modeChanges = <bool>[];
  Future<void>? createGate;
  Future<void>? endGate;
  List<CallRoom> incomingRooms = [];
  CallRoom latest = room;
  @override
  Future<CallConnection> create({
    required String workspaceId,
    required List<String> invitees,
    required bool video,
    required String threadId,
    required String title,
  }) async {
    creates++;
    await createGate;
    return CallConnection(
      token: 't',
      url: 'wss://call.example',
      room: room.copyWith(mode: video ? 'video' : 'audio'),
    );
  }

  @override
  Future<List<CallRoom>> incoming() async => incomingRooms;
  @override
  Future<CallConnection> join(CallRoom room) async {
    joins++;
    return const CallConnection(token: 't', url: 'wss://call.example');
  }

  @override
  Future<CallRoom> state(CallRoom room) async => latest;
  @override
  Future<void> decline(CallRoom room) async {
    declines++;
  }

  @override
  Future<void> end(CallRoom room) async {
    ends++;
    await endGate;
    if (endFails) throw const CallException('Нет сети');
  }

  @override
  Future<void> mode(CallRoom room, bool video) async {
    modeChanges.add(video);
    if (modeFails) throw const CallException('Нет доступа');
  }
}

class _Media extends CallMedia {
  bool permissionDenied = false, connectionFails = false;
  bool? prepared;
  Future<void>? prepareGate;
  Future<void>? cameraGate;
  int disconnections = 0, connects = 0;
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
  bool rejectScreen = false;
  @override
  Future<void> setScreenShare(bool enabled) async {
    if (!rejectScreen) screenSharing = enabled;
    notifyListeners();
  }

  bool speaker = false;
  @override
  int remoteCount = 0;
  @override
  Future<void> prepare(bool video) async {
    await prepareGate;
    if (permissionDenied) throw const CallException('Разрешите микрофон');
    prepared = video;
    microphone = true;
    camera = video;
  }

  @override
  Future<void> connect(CallConnection connection) async {
    connects++;
    if (connectionFails) throw const CallException('Нет соединения');
  }

  @override
  Future<void> setMicrophone(bool enabled) async {
    microphone = enabled;
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool enabled) async {
    await cameraGate;
    camera = enabled;
    notifyListeners();
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    speaker = enabled;
  }

  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> disconnect() async {
    disconnections++;
    microphone = false;
    camera = false;
    screenSharing = false;
  }
}

// LiveKit 2.13.2 does not re-export its iOS broadcast lifecycle manager.
// Keep this integration paired with the pinned SDK until it is public.
// ignore: implementation_imports
import 'package:livekit_client/src/managers/broadcast_manager.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'call_background_service.dart';
import 'package:livekit_client/livekit_client.dart';
import '../domain/call_media.dart';
import '../domain/call_repository.dart';
import '../domain/entities/call_connection.dart';

class LiveKitCallMedia extends CallMedia {
  LiveKitCallMedia({this.beforeCapture});
  final Future<void> Function()? beforeCapture;
  Room? room;
  LocalAudioTrack? _audio;
  LocalVideoTrack? _video;
  EventsListener<RoomEvent>? _events;
  bool _ended = false;
  bool _projectionActive = false;
  bool _broadcastObserved = false;
  CameraPosition _position = CameraPosition.front;
  @override
  bool get ended => _ended;
  @override
  bool get reconnecting =>
      room?.connectionState == ConnectionState.reconnecting;
  @override
  bool get microphone => room?.localParticipant?.isMicrophoneEnabled() ?? false;
  @override
  bool get camera => room?.localParticipant?.isCameraEnabled() ?? false;
  @override
  bool get screenSharing {
    final publication = room?.localParticipant?.getTrackPublicationBySource(
      TrackSource.screenShareVideo,
    );
    return publication?.track != null && publication?.muted == false;
  }

  @override
  int get remoteCount => room?.remoteParticipants.length ?? 0;
  @override
  Future<void> prepare(bool video) async {
    _ended = false;
    _position = CameraPosition.front;
    try {
      await beforeCapture?.call();
      await CallBackgroundService.requestNotifications();
      _audio = await LocalAudioTrack.create();
      await CallBackgroundService.start(camera: false);
      if (video) {
        _video = await LocalVideoTrack.createCameraTrack();
        await CallBackgroundService.start(camera: true);
      }
    } catch (_) {
      await disconnect();
      throw const CallException(
        'Не удалось включить микрофон или камеру. Проверьте разрешения в настройках устройства.',
      );
    }
  }

  @override
  Future<void> connect(CallConnection connection) async {
    final current = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
          useiOSBroadcastExtension: true,
          maxFrameRate: 15,
        ),
      ),
    );
    room = current;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !_broadcastObserved) {
      BroadcastManager().addListener(_onBroadcast);
      _broadcastObserved = true;
    }
    BroadcastManager().shouldPublishTrack = true;
    current.addListener(_changed);
    _events = current.createListener()
      ..on<RoomDisconnectedEvent>((event) {
        _ended = true;
        notifyListeners();
      });
    await current.connect(connection.url, connection.token);
    if (_audio != null) {
      await current.localParticipant!.publishAudioTrack(_audio!);
    }
    if (_video != null) {
      await current.localParticipant!.publishVideoTrack(_video!);
    }
    notifyListeners();
  }

  void _onBroadcast() {
    if (room == null && BroadcastManager().isBroadcasting) {
      unawaited(BroadcastManager().requestStop().catchError((Object _) {}));
    }
    notifyListeners();
  }

  void _changed() {
    if (_projectionActive && !screenSharing) {
      _projectionActive = false;
      unawaited(
        CallBackgroundService.start(
          camera: camera,
          screenShare: false,
        ).catchError((Object _) {}),
      );
    }
    notifyListeners();
  }

  @override
  Future<void> setScreenShare(bool enabled) async {
    final current = room;
    if (current == null) return;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (enabled && android) {
      final granted = await rtc.Helper.requestCapturePermission();
      if (!granted || !identical(room, current)) return;
      // Android requires permission first, then a promoted projection service,
      // and only then getDisplayMedia (used internally by LiveKit).
      await CallBackgroundService.start(camera: camera, screenShare: true);
    }
    try {
      if (!enabled && ios) await BroadcastManager().requestStop();
      await current.localParticipant?.setScreenShareEnabled(
        enabled,
        captureScreenAudio: false,
      );
      if (!identical(room, current)) {
        await current.localParticipant?.setScreenShareEnabled(false);
        return;
      }
      _projectionActive = enabled && android && screenSharing;
      if (android && !_projectionActive) {
        await CallBackgroundService.start(camera: camera, screenShare: false);
      }
      notifyListeners();
    } catch (_) {
      if (android && identical(room, current)) {
        await CallBackgroundService.start(camera: camera, screenShare: false);
      }
      rethrow;
    }
  }

  @override
  Future<void> setMicrophone(bool enabled) async {
    await room?.localParticipant?.setMicrophoneEnabled(enabled);
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool enabled) async {
    final activeRoom = room;
    if (activeRoom == null) return;
    await activeRoom.localParticipant?.setCameraEnabled(enabled);
    if (!identical(room, activeRoom)) return;
    try {
      await CallBackgroundService.start(camera: enabled);
    } catch (_) {
      if (enabled) await room?.localParticipant?.setCameraEnabled(false);
      rethrow;
    }
    notifyListeners();
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    await AudioManager.instance.setSpeakerOutputPreferred(enabled);
  }

  @override
  Future<void> switchCamera() async {
    _position = _position == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    final track = room?.localParticipant?.videoTrackPublications
        .where((p) => p.source == TrackSource.camera)
        .firstOrNull
        ?.track;
    if (track is LocalVideoTrack) await track.setCameraPosition(_position);
  }

  @override
  void dispose() {
    if (_broadcastObserved) BroadcastManager().removeListener(_onBroadcast);
    super.dispose();
  }

  @override
  Future<void> disconnect() async {
    final current = room;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      BroadcastManager().shouldPublishTrack = false;
      if (BroadcastManager().isBroadcasting) {
        try {
          await BroadcastManager().requestStop();
        } catch (_) {
          // A failed extension message must never retain the call's devices.
        }
      }
    }
    _projectionActive = false;
    final audio = _audio;
    final video = _video;
    final events = _events;
    room = null;
    _audio = null;
    _video = null;
    _events = null;
    current?.removeListener(_changed);
    Future<void> release(Future<dynamic> Function() operation) async {
      try {
        await operation();
      } catch (_) {
        /* Continue releasing the remaining devices. */
      }
    }

    await release(() async => events?.dispose());
    await release(() async => audio?.stop());
    await release(() async => video?.stop());
    await release(() async => current?.disconnect());
    await release(() async => audio?.dispose());
    await release(() async => video?.dispose());
    await release(() async => current?.dispose());
    await release(CallBackgroundService.stop);
  }
}

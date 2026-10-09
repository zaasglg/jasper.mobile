import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';

class VideoNoteCapture extends StatefulWidget {
  const VideoNoteCapture({super.key, required this.onSend});
  final Future<bool> Function(String path, int seconds) onSend;
  @override
  State<VideoNoteCapture> createState() => _VideoNoteCaptureState();
}

class _VideoNoteCaptureState extends State<VideoNoteCapture>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  VideoPlayerController? _player;
  File? _draft;
  Timer? _timer;
  final _watch = Stopwatch();
  int _seconds = 0;
  int _generation = 0;
  bool _recording = false;
  bool _busy = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize({CameraDescription? description}) async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    CameraController? controller;
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'Камера недоступна');
      }
      final selected =
          description ??
          _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          );
      final previous = _camera;
      _camera = null;
      await previous?.dispose();
      controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Не удалось открыть камеру. Проверьте разрешения камеры и микрофона в настройках.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive &&
        _camera?.value.isInitialized == true &&
        !_busy) {
      _suspend();
    }
    if (state == AppLifecycleState.resumed &&
        _camera == null &&
        _draft == null &&
        !_busy) {
      _initialize();
    }
  }

  Future<void> _suspend() async {
    if (_recording) await _stop();
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_busy || _camera == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _camera!.startVideoRecording();
      if (!mounted) return;
      _watch
        ..reset()
        ..start();
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds = _watch.elapsed.inSeconds);
        if (_seconds >= 60) _stop();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось начать запись. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy || !_recording || _camera == null) return;
    setState(() => _busy = true);
    _timer?.cancel();
    _watch.stop();
    try {
      final recording = await _camera!.stopVideoRecording();
      final file = File(recording.path);
      if (!mounted) {
        await _delete(file);
        return;
      }
      _draft = file;
      _seconds = _watch.elapsed.inSeconds.clamp(1, 60);
      setState(() => _recording = false);
      final player = VideoPlayerController.file(file);
      _player = player;
      await player.initialize();
      await player.setLooping(true);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _recording = false;
          _error =
              'Не удалось сохранить или просмотреть запись. Можно повторить запись.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retake() async {
    if (_busy || _sending) return;
    setState(() => _busy = true);
    await _player?.dispose();
    _player = null;
    final draft = _draft;
    _draft = null;
    if (draft != null) await _delete(draft);
    if (mounted) await _initialize(description: _camera?.description);
  }

  Future<void> _send() async {
    final draft = _draft;
    if (draft == null || _sending || _busy) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    await _player?.pause();
    try {
      final sent = await widget.onSend(draft.path, _seconds);
      if (!mounted) return;
      if (sent) {
        Navigator.pop(context);
      } else {
        setState(
          () => _error =
              'Не удалось отправить видеозаметку. Запись сохранена — повторите отправку.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось отправить запись. Максимальный размер — 25 МБ.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _camera?.dispose();
    _player?.dispose();
    final draft = _draft;
    if (draft != null) _delete(draft);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final camera = _camera;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: const Color(0xFF161525),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Видеозаметка'),
          leading: IconButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipOval(
                    child: ColoredBox(
                      color: Colors.black,
                      child: player?.value.isInitialized == true
                          ? ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: player!,
                              builder: (_, value, _) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoCover(controller: player),
                                  Center(
                                    child: IconButton.filledTonal(
                                      onPressed: () => value.isPlaying
                                          ? player.pause()
                                          : player.play(),
                                      icon: Icon(
                                        value.isPlaying
                                            ? LucideIcons.pause
                                            : LucideIcons.play,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : camera?.value.isInitialized == true
                          ? LayoutBuilder(
                              builder: (_, constraints) => FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height:
                                      MediaQuery.orientationOf(context) ==
                                          Orientation.portrait
                                      ? constraints.maxWidth *
                                            camera!.value.aspectRatio
                                      : constraints.maxWidth /
                                            camera!.value.aspectRatio,
                                  child: CameraPreview(camera),
                                ),
                              ),
                            )
                          : Center(
                              child: _busy
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      LucideIcons.cameraOff,
                                      color: Colors.white,
                                      size: 42,
                                    ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${_recording ? '● ' : ''}${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: _recording ? Colors.redAccent : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'До 60 секунд',
                  style: TextStyle(color: Colors.white60),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const Spacer(),
                if (_sending || _busy)
                  const CircularProgressIndicator(color: Colors.white)
                else if (_draft != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: _retake,
                        icon: const Icon(LucideIcons.rotateCcw),
                        label: const Text('Перезаписать'),
                      ),
                      FilledButton.icon(
                        onPressed: _send,
                        icon: const Icon(LucideIcons.sendHorizontal),
                        label: const Text('Отправить'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _recording || _cameras.length < 2
                            ? null
                            : () {
                                final next = _cameras.firstWhere(
                                  (item) =>
                                      item.name != camera?.description.name,
                                  orElse: () => _cameras.first,
                                );
                                _initialize(description: next);
                              },
                        icon: const Icon(
                          LucideIcons.switchCamera,
                          color: Colors.white,
                        ),
                      ),
                      IconButton.filled(
                        key: const Key('video-note-record'),
                        iconSize: 36,
                        style: IconButton.styleFrom(
                          backgroundColor: _recording
                              ? Colors.redAccent
                              : AppColors.accent,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: _recording
                            ? _stop
                            : camera == null
                            ? _initialize
                            : _start,
                        icon: Icon(
                          _recording ? LucideIcons.square : LucideIcons.video,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoCover extends StatelessWidget {
  const VideoCover({super.key, required this.controller});
  final VideoPlayerController controller;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.cover,
    child: SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    ),
  );
}

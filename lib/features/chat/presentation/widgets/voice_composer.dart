import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_theme.dart';

abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path:
          '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> dispose() => _recorder.dispose();
}

class VoiceComposer extends StatefulWidget {
  const VoiceComposer({
    super.key,
    required this.textField,
    required this.hasText,
    required this.isSending,
    required this.onTextSend,
    required this.onVoiceSend,
    this.recorder,
    this.onFiles,
    this.onVideo,
  });
  final Widget textField;
  final bool hasText;
  final bool isSending;
  final VoidCallback onTextSend;
  final Future<bool> Function(String path, int seconds) onVoiceSend;
  final VoiceRecorder? recorder;
  final VoidCallback? onFiles;
  final VoidCallback? onVideo;
  @override
  State<VoiceComposer> createState() => _VoiceComposerState();
}

class _VoiceComposerState extends State<VoiceComposer>
    with WidgetsBindingObserver {
  VoiceRecorder? _recorder;
  Timer? _timer;
  final _watch = Stopwatch();
  bool _recording = false;
  bool _busy = false;
  bool _held = false;
  bool _released = false;
  bool _cancelled = false;
  String? _draft;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_recording && !_busy) _finish(send: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recorder?.dispose();
    final draft = _draft;
    if (draft != null) _delete(draft);
    super.dispose();
  }

  Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _start() async {
    if (_busy || _recording || widget.isSending) return;
    _released = false;
    _cancelled = false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final recorder = _recorder ??= widget.recorder ?? DeviceVoiceRecorder();
      if (!await recorder.hasPermission()) {
        _error('Разрешите доступ к микрофону в настройках приложения.');
        return;
      }
      if (!mounted || _cancelled) return;
      await recorder.start();
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      _watch
        ..reset()
        ..start();
      setState(() {
        _recording = true;
        _seconds = 0;
        _busy = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds = _watch.elapsed.inSeconds);
        if (_seconds >= 300) _finish(send: false);
      });
      if (_cancelled) {
        await _cancel();
      } else if (_released) {
        await _finish();
      }
    } catch (_) {
      _error('Не удалось начать запись. Проверьте доступ к микрофону.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) {
      _cancelled = true;
      return;
    }
    setState(() => _busy = true);
    _timer?.cancel();
    _watch.stop();
    try {
      if (_recording) await _recorder?.cancel();
      if (_draft != null) await _delete(_draft!);
      if (mounted) {
        setState(() {
          _recording = false;
          _draft = null;
          _held = false;
        });
      }
    } catch (_) {
      _error('Не удалось отменить запись.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish({bool send = true}) async {
    if (_busy || widget.isSending) {
      _released = true;
      return;
    }
    setState(() => _busy = true);
    try {
      if (_recording) {
        _timer?.cancel();
        _watch.stop();
        _seconds = _watch.elapsed.inSeconds;
        _draft = await _recorder!.stop();
        if (!mounted) {
          if (_draft != null) await _delete(_draft!);
          return;
        }
        setState(() {
          _recording = false;
          _held = false;
        });
        if (_watch.elapsedMilliseconds < 500 || _draft == null) {
          if (_draft != null) await _delete(_draft!);
          _draft = null;
          _error('Запись слишком короткая.');
          return;
        }
        if (_seconds == 0) _seconds = 1;
      }
      if (!send || _draft == null) return;
      final draft = _draft!;
      final sent = await widget.onVoiceSend(draft, _seconds);
      if (sent) {
        await _delete(draft);
        if (mounted) setState(() => _draft = null);
      }
    } catch (_) {
      _error('Не удалось отправить запись. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = _recording || _draft != null;
    final blocked = _busy || widget.isSending;
    final time =
        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!voice && (widget.onFiles != null || widget.onVideo != null))
          PopupMenuButton<String>(
            key: const Key('chat-attachments'),
            tooltip: 'Прикрепить',
            enabled: !blocked,
            icon: const Icon(
              LucideIcons.plus,
              color: AppColors.accent,
              size: 22,
            ),
            onSelected: (value) => value == 'files'
                ? widget.onFiles?.call()
                : widget.onVideo?.call(),
            itemBuilder: (_) => [
              if (widget.onFiles != null)
                const PopupMenuItem(
                  value: 'files',
                  child: Row(
                    children: [
                      Icon(LucideIcons.paperclip, size: 20),
                      SizedBox(width: 12),
                      Text('Файлы'),
                    ],
                  ),
                ),
              if (widget.onVideo != null)
                const PopupMenuItem(
                  value: 'video',
                  child: Row(
                    children: [
                      Icon(LucideIcons.video, size: 20),
                      SizedBox(width: 12),
                      Text('Видеозаметка'),
                    ],
                  ),
                ),
            ],
          ),
        Expanded(
          child: voice
              ? Row(
                  children: [
                    IconButton(
                      key: const Key('voice-cancel'),
                      tooltip: 'Удалить запись',
                      onPressed: blocked ? null : _cancel,
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Colors.redAccent,
                      ),
                    ),
                    Icon(
                      _recording ? LucideIcons.mic : LucideIcons.audioLines,
                      size: 18,
                      color: _recording ? Colors.redAccent : AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _held
                            ? '← Отмена · ↑ Закрепить'
                            : _recording
                            ? 'Идёт запись…'
                            : 'Запись готова',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                )
              : widget.textField,
        ),
        const SizedBox(width: 7),
        GestureDetector(
          onLongPressStart: (_) {
            if (!voice && !widget.hasText && !blocked) {
              _held = true;
              _start();
            }
          },
          onLongPressMoveUpdate: (details) {
            if (details.offsetFromOrigin.dx < -70) {
              _held = false;
              _cancel();
            } else if (details.offsetFromOrigin.dy < -60 && mounted) {
              setState(() => _held = false);
            }
          },
          onLongPressEnd: (_) {
            if (_held) {
              _released = true;
              _finish();
            }
          },
          child: Semantics(
            label: voice
                ? 'Отправить запись'
                : widget.hasText
                ? 'Отправить сообщение'
                : 'Записать голосовое сообщение',
            child: IconButton.filled(
              key: Key(
                voice
                    ? 'voice-send'
                    : widget.hasText
                    ? 'conversation-send'
                    : 'voice-record',
              ),
              onPressed: blocked
                  ? null
                  : voice
                  ? _finish
                  : widget.hasText
                  ? widget.onTextSend
                  : _start,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.skeleton,
              ),
              icon: blocked
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      voice || widget.hasText
                          ? LucideIcons.sendHorizontal
                          : LucideIcons.mic,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

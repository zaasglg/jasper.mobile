import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/chat_attachment_loader.dart';
import 'video_note_capture.dart';

class VideoNoteMessage extends StatefulWidget {
  const VideoNoteMessage({super.key, required this.message});
  final ChatMessageModel message;
  @override
  State<VideoNoteMessage> createState() => _VideoNoteMessageState();
}

class _VideoNoteMessageState extends State<VideoNoteMessage> {
  VideoPlayerController? _player;
  File? _file;
  bool _busy = false;
  String? _error;
  Future<void> _toggle() async {
    if (_busy) return;
    try {
      if (_player == null) {
        setState(() {
          _busy = true;
          _error = null;
        });
        final url = widget.message.attachmentDataUrl;
        final bytes = url != null
            ? ChatAttachmentLoader.decodePayload(url)
            : await ChatAttachmentLoader(sl<Dio>()).load(widget.message.id);
        final extension = url?.startsWith('data:video/webm') == true
            ? 'webm'
            : 'mp4';
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/video-note-${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await file.writeAsBytes(bytes);
        if (!mounted) {
          await _delete(file);
          return;
        }
        _file = file;
        final player = VideoPlayerController.file(file);
        _player = player;
        await player.initialize();
        if (!mounted) return;
        setState(() => _busy = false);
      }
      final player = _player!;
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      await _player?.dispose();
      _player = null;
      final file = _file;
      _file = null;
      if (file != null) await _delete(file);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Повторить';
        });
      }
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _player?.dispose();
    final file = _file;
    if (file != null) _delete(file);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Semantics(
      label: 'Видеозаметка',
      button: true,
      child: SizedBox(
        width: 210,
        height: 210,
        child: ClipOval(
          child: Material(
            color: AppColors.accent.withValues(alpha: 0.15),
            child: InkWell(
              key: Key('video-note-${widget.message.id}'),
              onTap: _toggle,
              child: player?.value.isInitialized == true
                  ? ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: player!,
                      builder: (_, value, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoCover(controller: player),
                          if (!value.isPlaying)
                            const Center(
                              child: Icon(
                                LucideIcons.play,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          Positioned(
                            bottom: 24,
                            left: 40,
                            right: 40,
                            child: VideoProgressIndicator(
                              player,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: AppColors.accent,
                                backgroundColor: Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: _busy
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.video,
                                  size: 40,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error ??
                                      widget.message.formattedDuration ??
                                      'Видеозаметка',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

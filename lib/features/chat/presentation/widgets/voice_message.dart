import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message_model.dart';

class VoiceMessage extends StatefulWidget {
  const VoiceMessage({super.key, required this.message});
  final ChatMessageModel message;
  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<VoiceMessage> {
  AudioPlayer? _player;
  bool _loading = false;
  File? _file;
  @override
  void dispose() {
    _player?.dispose();
    final file = _file;
    if (file != null) _delete(file);
    super.dispose();
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_player == null) {
        setState(() => _loading = true);
        final data = UriData.parse(widget.message.transcript!);
        final extension = data.mimeType.contains('webm')
            ? 'webm'
            : data.mimeType.contains('ogg')
            ? 'ogg'
            : data.mimeType.contains('wav')
            ? 'wav'
            : 'm4a';
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/play-voice-${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await file.writeAsBytes(data.contentAsBytes());
        if (!mounted) {
          await _delete(file);
          return;
        }
        _file = file;
        final player = AudioPlayer();
        _player = player;
        await player.setFilePath(file.path);
        if (!mounted) return;
        setState(() => _loading = false);
      }
      final player = _player!;
      if (player.playing &&
          player.processingState != ProcessingState.completed) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        player.play().catchError((Object error) {
          if (mounted) _error();
        });
      }
    } catch (_) {
      await _player?.dispose();
      _player = null;
      if (mounted) {
        setState(() => _loading = false);
        _error();
      }
    }
  }

  void _error() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Не удалось воспроизвести запись. Попробуйте ещё раз.'),
    ),
  );
  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final playable =
        widget.message.transcript?.startsWith('data:audio/') == true;
    return SizedBox(
      width: 250,
      child: StreamBuilder<PlayerState>(
        stream: _player?.playerStateStream,
        builder: (context, state) {
          final playing =
              state.data?.playing == true &&
              state.data?.processingState != ProcessingState.completed;
          return Row(
            children: [
              IconButton.filled(
                key: Key('voice-play-${widget.message.id}'),
                tooltip: playing ? 'Пауза' : 'Воспроизвести',
                onPressed: playable && !_loading ? _toggle : null,
                style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        playing ? LucideIcons.pause : LucideIcons.play,
                        size: 19,
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player?.positionStream,
                  builder: (context, position) {
                    final duration =
                        _player?.duration ??
                        Duration(seconds: widget.message.durationSeconds ?? 0);
                    final current = position.data ?? Duration.zero;
                    final max = duration.inMilliseconds.toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: current.inMilliseconds.toDouble().clamp(
                              0,
                              max > 0 ? max : 1,
                            ),
                            max: max > 0 ? max : 1,
                            activeColor: AppColors.accent,
                            onChanged: _player == null
                                ? null
                                : (value) => _player?.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            playable
                                ? '${_time(current)} / ${_time(duration)}'
                                : 'Запись недоступна',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message_model.dart';

abstract interface class VoicePlayback {
  bool get playing;
  ProcessingState get processingState;
  Duration? get duration;
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Future<void> setUrl(String url);
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class DeviceVoicePlayback implements VoicePlayback {
  final AudioPlayer _player = AudioPlayer();
  @override
  bool get playing => _player.playing;
  @override
  ProcessingState get processingState => _player.processingState;
  @override
  Duration? get duration => _player.duration;
  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> setFilePath(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> dispose() => _player.dispose();
}

class VoiceMessage extends StatefulWidget {
  const VoiceMessage({super.key, required this.message, this.playerFactory});
  final ChatMessageModel message;
  final VoicePlayback Function()? playerFactory;
  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<VoiceMessage> {
  VoicePlayback? _player;
  int _generation = 0;
  bool _loading = false;
  File? _file;
  @override
  void dispose() {
    unawaited(_reset());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.transcript != widget.message.transcript) {
      unawaited(_reset());
    }
  }

  Future<void> _reset() async {
    _generation++;
    final player = _player;
    final file = _file;
    _player = null;
    _file = null;
    _loading = false;
    try {
      await player?.dispose();
    } catch (_) {
      /* Allow retry after platform failures. */
    }
    if (file != null) await _delete(file);
  }

  Future<void> _fail(int generation) async {
    if (!mounted || generation != _generation) return;
    final reset = _reset();
    setState(() {});
    _error();
    await reset;
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_loading) return;
    final generation = _generation;
    try {
      if (_player == null) {
        setState(() => _loading = true);
        final source = widget.message.transcript!;
        final remote = Uri.tryParse(source);
        if (remote?.scheme == 'https' && remote!.host.isNotEmpty) {
          final player = widget.playerFactory?.call() ?? DeviceVoicePlayback();
          _player = player;
          await player.setUrl(remote.removeFragment().toString());
          if (!mounted || generation != _generation) return;
          setState(() => _loading = false);
        } else {
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
          if (!mounted || generation != _generation) {
            await _delete(file);
            return;
          }
          _file = file;
          final player = widget.playerFactory?.call() ?? DeviceVoicePlayback();
          _player = player;
          await player.setFilePath(file.path);
          if (!mounted || generation != _generation) return;
          setState(() => _loading = false);
        }
      }
      final player = _player!;
      if (player.playing &&
          player.processingState != ProcessingState.completed) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        if (!mounted || generation != _generation) return;
        player.play().catchError((Object error) {
          unawaited(_fail(generation));
        });
      }
    } catch (_) {
      await _fail(generation);
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
        widget.message.transcript?.startsWith('data:audio/') == true ||
        (Uri.tryParse(widget.message.transcript ?? '')?.scheme == 'https');
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
                        color: Colors.white,
                        size: AppIconSizes.standard,
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
                            trackHeight: 28,
                            trackShape: const _VoiceWaveformTrack(),
                            inactiveTrackColor: AppColors.accent.withValues(
                              alpha: 0.22,
                            ),
                            disabledInactiveTrackColor: AppColors.accent
                                .withValues(alpha: 0.22),
                            disabledActiveTrackColor: AppColors.accent,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4,
                              disabledThumbRadius: 4,
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

/// Decorative waveform; playback progress and seeking use the audio duration.
class _VoiceWaveformTrack extends SliderTrackShape {
  const _VoiceWaveformTrack();

  static const _heights = [
    .18,
    .32,
    .55,
    .28,
    .72,
    .92,
    .48,
    .65,
    .36,
    .22,
    .52,
    .78,
    1.0,
    .62,
    .42,
    .7,
    .9,
    .54,
    .3,
    .46,
    .68,
    .38,
    .24,
    .56,
    .84,
    .64,
    .4,
    .76,
    .5,
    .26,
    .44,
    .6,
    .34,
    .2,
    .48,
    .7,
    .46,
    .3,
    .18,
    .36,
  ];

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const inset = 8.0;
    final height = sliderTheme.trackHeight ?? 28;
    return Rect.fromLTWH(
      offset.dx + inset,
      offset.dy + (parentBox.size.height - height) / 2,
      (parentBox.size.width - inset * 2).clamp(0.0, double.infinity),
      height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    if (rect.width <= 0) return;
    final active = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    ).evaluate(enableAnimation)!;
    final inactive = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    final count = (rect.width / 5).floor().clamp(1, _heights.length);
    final spacing = rect.width / count;
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = rect.left + (i + .5) * spacing;
      final height = rect.height * _heights[i * _heights.length ~/ count];
      final played = textDirection == TextDirection.ltr
          ? x < thumbCenter.dx
          : x > thumbCenter.dx;
      paint.color = played ? active : inactive;
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, rect.center.dy),
            width: 2.5,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }
}

import 'package:jospar/core/localization/app_translations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../data/livekit_call_media.dart';
import 'call_cubit.dart';

abstract final class _CallStyle {
  static const background = Color(0xff0b141a);
  static const surface = Color(0xff202c33);
  static const secondary = Color(0xffaebac1);
  static const green = Color(0xff00a884);
  static const danger = Color(0xffef4444);
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CallCubit, CallState>(
    bloc: sl<CallCubit>(),
    builder: (context, state) {
      final cubit = sl<CallCubit>();
      final media = cubit.media;
      final native = media is LiveKitCallMedia ? media.room : null;
      final participants = <lk.Participant>[
        if (native?.localParticipant != null) native!.localParticipant!,
        ...?native?.remoteParticipants.values,
      ];
      final sharedScreens = [
        for (final peer in participants)
          for (final publication in peer.videoTrackPublications)
            if (publication.source == lk.TrackSource.screenShareVideo &&
                publication.track is lk.VideoTrack &&
                !publication.muted)
              (
                peer: peer,
                track: publication.track as lk.VideoTrack,
                id: publication.sid,
                local: peer == native?.localParticipant,
              ),
      ];
      final elapsed = state.startedAt == null
          ? Duration.zero
          : DateTime.now().difference(state.startedAt!);
      final time =
          '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      final status = switch (state.phase) {
        CallPhase.preparing => 'Подготовка устройств…',
        CallPhase.connecting => 'Подключение…',
        CallPhase.active =>
          media.reconnecting
              ? 'Восстанавливаем соединение…'
              : media.remoteCount == 0
              ? 'Ожидаем участников…'
              : time,
        CallPhase.ending => 'Завершаем звонок…',
        CallPhase.failed => 'Не удалось начать звонок',
        _ => 'Звонок завершён',
      };
      final remotePeers = participants
          .where((peer) => peer != native?.localParticipant)
          .toList();
      final hasVideo = participants.any((peer) {
        final publication = peer.getTrackPublicationBySource(
          lk.TrackSource.camera,
        );
        return publication?.track is lk.VideoTrack &&
            publication?.muted != true;
      });
      final name = state.room?.title.isNotEmpty == true
          ? state.room!.title
          : 'Звонок';
      final pictureInPicture =
          state.phase == CallPhase.active &&
          remotePeers.length == 1 &&
          native?.localParticipant != null &&
          sharedScreens.isEmpty &&
          hasVideo;
      final groupGrid =
          state.phase == CallPhase.active &&
          remotePeers.length > 1 &&
          sharedScreens.isEmpty;
      return Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _CallStyle.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: _CallStyle.background,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        child: Scaffold(
          backgroundColor: _CallStyle.background,
          extendBodyBehindAppBar: pictureInPicture || groupGrid,
          appBar: AppBar(
            backgroundColor: pictureInPicture || groupGrid
                ? Colors.transparent
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: _CallStyle.secondary),
                SizedBox(width: 6),
                Text(
                  tr(context, 'Звонок'),
                  style: TextStyle(fontSize: 13, color: _CallStyle.secondary),
                ),
              ],
            ),
            leading: IconButton(
              tooltip: state.busy
                  ? tr(context, 'Свернуть звонок')
                  : tr(context, 'Закрыть'),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/messenger'),
              icon: Icon(
                state.busy ? Icons.keyboard_arrow_down : Icons.close,
                size: 22,
              ),
            ),
          ),
          body: groupGrid
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CallParticipantLayout(
                      edgeToEdge: true,
                      children: [
                        for (final participant in participants)
                          _Peer(
                            key: ValueKey(participant.identity),
                            participant: participant,
                            local: participant == native?.localParticipant,
                            fullscreen: true,
                          ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: _CallStyle.background.withValues(alpha: .6),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.error != null)
                                  Text(
                                    tr(context, state.error!),
                                    textAlign: TextAlign.center,
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      tooltip: tr(context, 'Развернуть камеру'),
                                      icon: const Icon(
                                        Icons.cameraswitch_outlined,
                                      ),
                                      onPressed:
                                          !media.camera || state.controlsBusy
                                          ? null
                                          : () => cubit.control('switch'),
                                    ),
                                    IconButton(
                                      tooltip: media.camera
                                          ? tr(context, 'Выключить камеру')
                                          : tr(context, 'Включить камеру'),
                                      icon: Icon(
                                        media.camera
                                            ? Icons.videocam_outlined
                                            : Icons.videocam_off_outlined,
                                      ),
                                      onPressed: state.controlsBusy
                                          ? null
                                          : () => cubit.control('camera'),
                                    ),
                                    IconButton.filled(
                                      tooltip: tr(context, 'Отключиться'),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _CallStyle.danger,
                                        foregroundColor: Colors.white,
                                        fixedSize: const Size.square(64),
                                      ),
                                      icon: const Icon(
                                        Icons.call_end,
                                        size: 30,
                                      ),
                                      onPressed: () => cubit.finish(),
                                    ),
                                    IconButton(
                                      tooltip: media.microphone
                                          ? tr(context, 'Выключить микрофон')
                                          : tr(context, 'Включить микрофон'),
                                      icon: Icon(
                                        media.microphone
                                            ? Icons.mic_none
                                            : Icons.mic_off_outlined,
                                      ),
                                      onPressed: state.controlsBusy
                                          ? null
                                          : () => cubit.control('microphone'),
                                    ),
                                    IconButton(
                                      tooltip: tr(context, 'Показать экран'),
                                      icon: const Icon(
                                        Icons.screen_share_outlined,
                                      ),
                                      onPressed: state.controlsBusy
                                          ? null
                                          : () => cubit.control('screen'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pictureInPicture)
                      CallPictureInPicture(
                        remote: _Peer(
                          participant: remotePeers.single,
                          local: false,
                          fullscreen: true,
                        ),
                        local: _Peer(
                          participant: native!.localParticipant!,
                          local: true,
                          showLabel: false,
                        ),
                      ),
                    SafeArea(
                      child: Column(
                        children: [
                          if (pictureInPicture)
                            const SizedBox(height: kToolbarHeight),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 24,
                              left: 24,
                              right: 24,
                            ),
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 15,
                                color: _CallStyle.secondary,
                              ),
                            ),
                          ),
                          if (state.busy && sharedScreens.isNotEmpty) ...[
                            Expanded(
                              child: PageView(
                                children: [
                                  for (final screen in sharedScreens)
                                    CallScreenShareView(
                                      key: ValueKey(screen.id),
                                      track: screen.track,
                                      name: screen.peer.name,
                                      local: screen.local,
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 105,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: participants.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) => SizedBox(
                                  width: 145,
                                  child: _Peer(
                                    participant: participants[i],
                                    local:
                                        participants[i] ==
                                        native?.localParticipant,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: pictureInPicture
                                  ? const SizedBox.expand()
                                  : !state.busy ||
                                        (!hasVideo && remotePeers.length <= 1)
                                  ? Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            UserAvatar(
                                              size: 144,
                                              name:
                                                  state.busy &&
                                                      remotePeers.isNotEmpty &&
                                                      remotePeers
                                                          .first
                                                          .name
                                                          .isNotEmpty
                                                  ? remotePeers.first.name
                                                  : name,
                                              userId:
                                                  state.busy &&
                                                      remotePeers.isNotEmpty
                                                  ? remotePeers.first.identity
                                                  : null,
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        ),
                                      ),
                                    )
                                  : CallParticipantLayout(
                                      children: [
                                        for (final participant in participants)
                                          _Peer(
                                            key: ValueKey(participant.identity),
                                            participant: participant,
                                            local:
                                                participant ==
                                                native?.localParticipant,
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                tr(context, state.error!),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.of(context).error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (state.phase == CallPhase.ended &&
                              state.error != null &&
                              state.room != null &&
                              (state.creator || state.room!.endOnHangup))
                            TextButton(
                              onPressed: () => cubit.finish(endForAll: true),
                              child: Text(
                                tr(context, 'Повторить завершение на сервере'),
                              ),
                            ),
                          if (state.phase == CallPhase.active)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 20,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Control(
                                    label: media.microphone
                                        ? 'Микрофон'
                                        : 'Без звука',
                                    icon: media.microphone
                                        ? Icons.mic_none
                                        : Icons.mic_off_outlined,
                                    selected: !media.microphone,
                                    onTap: state.controlsBusy
                                        ? null
                                        : () => cubit.control('microphone'),
                                  ),
                                  _Control(
                                    label: media.camera
                                        ? 'Камера'
                                        : 'Без видео',
                                    icon: media.camera
                                        ? Icons.videocam_outlined
                                        : Icons.videocam_off_outlined,
                                    selected: media.camera,
                                    onTap: state.controlsBusy
                                        ? null
                                        : () => cubit.control('camera'),
                                  ),
                                  _Control(
                                    label: state.speaker
                                        ? 'Динамик'
                                        : 'Телефон',
                                    icon: state.speaker
                                        ? Icons.volume_up_outlined
                                        : Icons.hearing_outlined,
                                    selected: state.speaker,
                                    onTap: state.controlsBusy
                                        ? null
                                        : () => cubit.control('speaker'),
                                  ),
                                  _Control(
                                    label: media.screenSharing
                                        ? 'Остановить экран'
                                        : 'Экран',
                                    icon: media.screenSharing
                                        ? Icons.stop_screen_share_outlined
                                        : Icons.screen_share_outlined,
                                    selected: media.screenSharing,
                                    onTap: state.controlsBusy
                                        ? null
                                        : () => cubit.control('screen'),
                                  ),
                                  if (media.camera)
                                    _Control(
                                      label: 'Развернуть',
                                      icon: Icons.cameraswitch_outlined,
                                      onTap: state.controlsBusy
                                          ? null
                                          : () => cubit.control('switch'),
                                    ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: state.busy
                                ? IconButton.filled(
                                    tooltip: state.creator
                                        ? tr(context, 'Завершить звонок')
                                        : tr(context, 'Отключиться'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _CallStyle.danger,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(72, 72),
                                      shape: const CircleBorder(),
                                    ),
                                    onPressed: state.phase == CallPhase.ending
                                        ? null
                                        : () => cubit.finish(),
                                    icon: const Icon(Icons.call_end, size: 30),
                                  )
                                : FilledButton(
                                    key: const Key('call_close'),
                                    onPressed: () => context.canPop()
                                        ? context.pop()
                                        : context.go('/messenger'),
                                    child: Text(tr(context, 'Закрыть')),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

/// One-to-one video: remote fills the display; self preview stays in a safe area.
class CallPictureInPicture extends StatefulWidget {
  const CallPictureInPicture({
    super.key,
    required this.remote,
    required this.local,
  });

  final Widget remote;
  final Widget local;

  @override
  State<CallPictureInPicture> createState() => _CallPictureInPictureState();
}

class _CallPictureInPictureState extends State<CallPictureInPicture> {
  // Fractions preserve the position across timer rebuilds and orientation changes.
  Offset _position = const Offset(1, .27);

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.remote,
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0, .45, 1],
            ),
          ),
        ),
      ),
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth * .28).clamp(72.0, 120.0);
            final height = width * 4 / 3;
            final horizontalTravel =
                (constraints.maxWidth - width - AppSpacing.md * 2).clamp(
                  0.0,
                  double.infinity,
                );
            final top = kToolbarHeight + AppSpacing.sm;
            final verticalTravel =
                (constraints.maxHeight -
                        top -
                        height -
                        AppSpacing.touchTarget * 4)
                    .clamp(0.0, double.infinity);
            return Stack(
              children: [
                Positioned(
                  left: AppSpacing.md + horizontalTravel * _position.dx,
                  top: top + verticalTravel * _position.dy,
                  width: width,
                  height: height,
                  child: GestureDetector(
                    key: const Key('call_self_preview'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => setState(() {
                      _position = Offset(
                        horizontalTravel == 0
                            ? 0
                            : (_position.dx +
                                      details.delta.dx / horizontalTravel)
                                  .clamp(0.0, 1.0),
                        verticalTravel == 0
                            ? 0
                            : (_position.dy + details.delta.dy / verticalTravel)
                                  .clamp(0.0, 1.0),
                      );
                    }),
                    child: Semantics(
                      label: tr(
                        context,
                        'Ваше видео. Можно перемещать по экрану',
                      ),
                      child: widget.local,
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
}

/// Fits every participant into the space left above the call controls.
class CallParticipantLayout extends StatelessWidget {
  const CallParticipantLayout({
    super.key,
    required this.children,
    this.edgeToEdge = false,
  });

  final List<Widget> children;
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: edgeToEdge ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.md),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();
        final columns =
            constraints.maxWidth > constraints.maxHeight || children.length > 2
            ? 2
            : 1;
        final rows = (children.length / columns).ceil();
        return Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0 && !edgeToEdge)
                const SizedBox(height: AppSpacing.smMd),
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0 && !edgeToEdge)
                        const SizedBox(width: AppSpacing.smMd),
                      Expanded(
                        child: row * columns + column < children.length
                            ? children[row * columns + column]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: label,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: selected ? Colors.white : _CallStyle.surface,
            foregroundColor: selected ? _CallStyle.background : Colors.white,
            minimumSize: const Size(
              AppSpacing.touchTarget,
              AppSpacing.touchTarget,
            ),
          ),
          icon: Icon(icon, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: _CallStyle.secondary),
        ),
      ],
    ),
  );
}

class _Peer extends StatelessWidget {
  const _Peer({
    super.key,
    required this.participant,
    required this.local,
    this.fullscreen = false,
    this.showLabel = true,
  });
  final lk.Participant participant;
  final bool local;
  final bool fullscreen;
  final bool showLabel;
  @override
  Widget build(BuildContext context) {
    final publication = participant.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    final video = track is lk.VideoTrack && publication?.muted != true;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _CallStyle.surface,
        borderRadius: BorderRadius.circular(fullscreen ? 0 : AppRadius.lg),
        border: fullscreen
            ? null
            : Border.all(
                color: participant.isSpeaking
                    ? _CallStyle.green
                    : _CallStyle.surface,
                width: participant.isSpeaking ? 2 : 1,
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video)
            lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover)
          else
            Center(
              child: UserAvatar(
                size: 64,
                userId: participant.identity,
                name: participant.name.isEmpty ? 'Участник' : participant.name,
              ),
            ),
          if (showLabel && !fullscreen)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  if (!participant.isMicrophoneEnabled())
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.mic_off_outlined,
                        size: 16,
                        color: AppColors.of(context).error,
                      ),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _CallStyle.background.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${participant.name.isEmpty ? 'Участник' : participant.name}${local ? ' (вы)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Screen content keeps its full aspect ratio and can be zoomed independently
/// from the participant tiles. Never crop slides, documents or phone screens.
class CallScreenShareView extends StatelessWidget {
  const CallScreenShareView({
    super.key,
    required this.track,
    required this.name,
    this.local = false,
  });
  final lk.VideoTrack track;
  final String name;
  final bool local;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: const Color(0xff171722),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.screen_share_outlined,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      local
                          ? tr(context, 'Вы демонстрируете экран')
                          : tr(context, "Экран · {p0}", {
                              'p0': name.isEmpty ? 'Участник' : name,
                            }),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: local
                  ? Center(
                      child: Text(
                        tr(
                          context,
                          'Перейдите в приложение, которое хотите показать.\nОстановить трансляцию можно кнопкой ниже.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    )
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: SizedBox.expand(
                        child: lk.VideoTrackRenderer(
                          track,
                          fit: lk.VideoViewFit.contain,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

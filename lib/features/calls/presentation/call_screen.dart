import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../data/livekit_call_media.dart';
import 'call_cubit.dart';

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
      return Scaffold(
        backgroundColor: const Color(0xfff7f7fa),
        appBar: AppBar(
          title: Text(
            state.room?.title.isNotEmpty == true ? state.room!.title : 'Звонок',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: state.busy ? 'Свернуть звонок' : 'Закрыть',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/messenger'),
            icon: Icon(
              state.busy ? Icons.keyboard_arrow_down : Icons.close,
              size: 22,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              if (sharedScreens.isNotEmpty) ...[
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: participants.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => SizedBox(
                      width: 145,
                      child: _Peer(
                        participant: participants[i],
                        local: participants[i] == native?.localParticipant,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: participants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserAvatar(
                                size: 88,
                                name: state.room?.callerName.isNotEmpty == true
                                    ? state.room!.callerName
                                    : state.room?.title ?? 'Звонок',
                                avatarUrl: state.room?.callerAvatar,
                                userId: state.room?.callerId,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                state.room?.callerName ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: participants.length > 2 ? 2 : 1,
                                childAspectRatio: participants.length == 1
                                    ? 1
                                    : 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: participants.length,
                          itemBuilder: (_, i) => _Peer(
                            participant: participants[i],
                            local: participants[i] == native?.localParticipant,
                          ),
                        ),
                ),
              ],
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
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
                  child: const Text('Повторить завершение на сервере'),
                ),
              if (state.phase == CallPhase.active)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Control(
                        label: media.microphone ? 'Микрофон' : 'Без звука',
                        icon: media.microphone
                            ? Icons.mic_none
                            : Icons.mic_off_outlined,
                        selected: !media.microphone,
                        onTap: state.controlsBusy
                            ? null
                            : () => cubit.control('microphone'),
                      ),
                      _Control(
                        label: media.camera ? 'Камера' : 'Без видео',
                        icon: media.camera
                            ? Icons.videocam_outlined
                            : Icons.videocam_off_outlined,
                        selected: media.camera,
                        onTap: state.controlsBusy
                            ? null
                            : () => cubit.control('camera'),
                      ),
                      _Control(
                        label: state.speaker ? 'Динамик' : 'Телефон',
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
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: state.phase == CallPhase.ending
                            ? null
                            : () => cubit.finish(),
                        icon: const Icon(Icons.call_end, size: 22),
                        label: Text(
                          state.creator ? 'Завершить звонок' : 'Отключиться',
                        ),
                      )
                    : FilledButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/messenger'),
                        child: const Text('Закрыть'),
                      ),
              ),
            ],
          ),
        ),
      );
    },
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        tooltip: label,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: selected ? const Color(0xffebe7ff) : Colors.white,
          foregroundColor: selected ? AppColors.accent : AppColors.ink,
          minimumSize: const Size(52, 52),
        ),
        icon: Icon(icon, size: 22),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
    ],
  );
}

class _Peer extends StatelessWidget {
  const _Peer({required this.participant, required this.local});
  final lk.Participant participant;
  final bool local;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: participant.isSpeaking
              ? AppColors.accent
              : const Color(0xffe6e6ec),
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
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                if (!participant.isMicrophoneEnabled())
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.mic_off_outlined,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
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
                          ? 'Вы демонстрируете экран'
                          : 'Экран · ${name.isEmpty ? 'Участник' : name}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: local
                  ? const Center(
                      child: Text(
                        'Перейдите в приложение, которое хотите показать.\nОстановить трансляцию можно кнопкой ниже.',
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

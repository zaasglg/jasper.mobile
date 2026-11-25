import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/services/channel_photo_picker.dart';
import '../../domain/repositories/channel_image_repository.dart';
import '../channel_photo_strings.dart';
import '../cubit/channel_info_cubit.dart';
import 'channel_avatar.dart';

Future<void> showChannelInfo(
  BuildContext context,
  ChatConversationModel channel,
  ChannelImageRepository repository, {
  ChannelPhotoPicker? picker,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BlocProvider(
    create: (_) => ChannelInfoCubit(
      repository,
      picker ??
          (sl.isRegistered<ChannelPhotoPicker>()
              ? sl<ChannelPhotoPicker>()
              : GalleryChannelPhotoPicker()),
      channel.id,
    )..load(),
    child: ChannelInfoSheet(channel: channel, repository: repository),
  ),
);

class ChannelInfoSheet extends StatelessWidget {
  const ChannelInfoSheet({
    super.key,
    required this.channel,
    required this.repository,
  });
  final ChatConversationModel channel;
  final ChannelImageRepository repository;
  @override
  Widget build(BuildContext context) {
    final strings = ChannelPhotoStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return BlocBuilder<ChannelInfoCubit, ChannelInfoState>(
      builder: (context, state) {
        final cubit = context.read<ChannelInfoCubit>();
        final info = state.info;
        final url = info == null ? channel.imageUrl : info.imageUrl;
        return PopScope(
          canPop: !state.saving,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.info,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.close,
                          onPressed: state.saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ChannelAvatar(
                        channelId: channel.id,
                        size: 80,
                        imageUrl: url,
                        repository: repository,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      channel.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    if (state.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (info?.canManageImage == true) ...[
                      TextButton.icon(
                        key: const Key('channel-photo-choose'),
                        onPressed: state.saving ? null : cubit.choosePhoto,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 20,
                        ),
                        label: Text(
                          url == null || url.isEmpty
                              ? strings.choose
                              : strings.replace,
                        ),
                      ),
                      if (url != null && url.isNotEmpty)
                        TextButton.icon(
                          key: const Key('channel-photo-remove'),
                          onPressed: state.saving ? null : cubit.removePhoto,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: Text(strings.remove),
                        ),
                    ],
                    if (state.saving)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: Text(strings.saving)),
                          ],
                        ),
                      ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            strings.error(state.error!),
                            key: const Key('channel-photo-error'),
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ),
                    if (info == null && !state.loading)
                      TextButton(
                        onPressed: cubit.load,
                        child: Text(strings.retry),
                      ),
                    if (info != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${strings.members} · ${info.members.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      for (final member in info.members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(
                            size: 32,
                            name: member.name,
                            avatarUrl: member.avatarUrl,
                          ),
                          title: Text(member.name),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

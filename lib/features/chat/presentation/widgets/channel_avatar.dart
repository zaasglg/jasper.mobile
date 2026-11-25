import '../../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/widgets/user_avatar.dart' show resolveUserAvatarUrl;
import '../../domain/repositories/channel_image_repository.dart';
import '../../domain/repositories/chat_repository.dart';

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.channelId,
    required this.size,
    this.imageUrl,
    this.repository,
  });
  final String channelId;
  final double size;
  final String? imageUrl;
  final ChannelImageRepository? repository;
  @override
  Widget build(BuildContext context) {
    final source =
        repository ??
        (sl.isRegistered<ChatRepository>() &&
                sl<ChatRepository>() is ChannelImageRepository
            ? sl<ChatRepository>() as ChannelImageRepository
            : null);
    return StreamBuilder<ChannelImageUpdate>(
      key: ValueKey(channelId),
      stream: source?.channelImageChanges.where(
        (e) => e.channelId == channelId,
      ),
      initialData: source?.channelImageSnapshot(channelId),
      builder: (context, snapshot) {
        final cached = source?.channelImageSnapshot(channelId);
        final streamed = snapshot.data;
        final update =
            cached != null &&
                (streamed == null || cached.revision > streamed.revision)
            ? cached
            : streamed;
        final value = update == null ? imageUrl : update.imageUrl;
        final url = resolveUserAvatarUrl(value);
        final dark = Theme.of(context).brightness == Brightness.dark;
        Widget fallback() => ColoredBox(
          color: AppColors.accent.withValues(alpha: dark ? .22 : .1),
          child: Center(
            child: Icon(
              LucideIcons.users,
              size: size * .5,
              color: dark ? const Color(0xFFC7BFFF) : AppColors.accent,
            ),
          ),
        );
        Widget content = fallback();
        if (url != null) {
          if (url.startsWith('data:image/')) {
            try {
              content = Image.memory(
                UriData.parse(url).contentAsBytes(),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback(),
              );
            } on FormatException {
              content = fallback();
            }
          } else {
            final token = sl.isRegistered<AuthTokenStorage>()
                ? sl<AuthTokenStorage>().cachedToken
                : null;
            content = CachedNetworkImage(
              imageUrl: url,
              cacheKey: 'channel:$channelId:${update?.revision ?? url}',
              httpHeaders: ApiConstants.isSameOrigin(url) && token != null
                  ? {'Authorization': 'Bearer $token'}
                  : const {},
              fit: BoxFit.cover,
              alignment: Alignment.center,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => fallback(),
              errorWidget: (_, _, _) => fallback(),
            );
          }
        }
        return ClipOval(
          child: SizedBox.square(dimension: size, child: content),
        );
      },
    );
  }
}

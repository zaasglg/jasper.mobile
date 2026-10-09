import '../../../../core/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.avatarUrl,
    this.iconSize,
    this.iconColor,
  });

  final double size;
  final String? avatarUrl;
  final double? iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final url = resolveUserAvatarUrl(avatarUrl);
    if (url == null) return _fallback();
    return UserAvatar(size: size, avatarUrl: url);
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F1F5),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.user,
        size: iconSize ?? size * 0.52,
        color: iconColor ?? const Color(0xFF9AA0A6),
      ),
    );
  }
}

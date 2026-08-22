import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.avatarUrl,
    this.iconSize,
  });

  final double size;
  final String? avatarUrl;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) return _fallback();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => _fallback(),
        errorWidget: (context, _, _) => _fallback(),
      ),
    );
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
        color: const Color(0xFF9AA0A6),
      ),
    );
  }
}

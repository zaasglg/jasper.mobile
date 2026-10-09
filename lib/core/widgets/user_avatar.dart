import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../di/service_locator.dart';
import '../network/user_avatar_repository.dart';
import '../storage/auth_token_storage.dart';
import '../theme/app_theme.dart';

String? resolveUserAvatarUrl(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('data:image/')) return source;
  final uri = Uri.tryParse(source);
  if (uri == null) return null;
  final resolved = Uri.parse('https://jospar.me/').resolveUri(uri);
  return ['https', 'http'].contains(resolved.scheme)
      ? resolved.toString()
      : null;
}

class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.userId,
    this.name = '',
    this.avatarUrl,
    this.backgroundColor = AppColors.accent,
    this.foregroundColor = Colors.white,
  });
  final double size;
  final String? userId;
  final String name;
  final String? avatarUrl;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _resolved;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.avatarUrl != widget.avatarUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    _resolved = resolveUserAvatarUrl(widget.avatarUrl);
    final id = widget.userId;
    if (_resolved != null ||
        id == null ||
        id.isEmpty ||
        !sl.isRegistered<UserAvatarRepository>()) {
      return;
    }
    final url = await sl<UserAvatarRepository>().avatarFor(id);
    if (mounted && revision == _revision) {
      setState(() => _resolved = resolveUserAvatarUrl(url));
    }
  }

  Widget _fallback() {
    final initials = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person_outline,
                size: widget.size * 0.5,
                color: widget.foregroundColor,
              )
            : Text(
                initials,
                style: TextStyle(
                  fontSize: widget.size * 0.32,
                  fontWeight: FontWeight.w700,
                  color: widget.foregroundColor,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolved;
    final token = sl.isRegistered<AuthTokenStorage>()
        ? sl<AuthTokenStorage>().cachedToken
        : null;
    final sameOrigin = url != null && Uri.tryParse(url)?.host == 'jospar.me';
    final headers = sameOrigin && token != null && token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : <String, String>{};
    Widget content = _fallback();
    if (url != null) {
      if (url.startsWith('data:image/')) {
        try {
          final data = UriData.parse(url);
          content = Image.memory(
            data.contentAsBytes(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          );
        } on FormatException {
          content = _fallback();
        }
      } else if (Uri.parse(url).path.toLowerCase().endsWith('.svg')) {
        content = SvgPicture.network(
          url,
          headers: headers,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => _fallback(),
          errorBuilder: (_, _, _) => _fallback(),
        );
      } else {
        content = CachedNetworkImage(
          imageUrl: url,
          httpHeaders: headers,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        );
      }
    }
    return Semantics(
      label: widget.name.isEmpty ? 'Аватар пользователя' : widget.name,
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: content,
        ),
      ),
    );
  }
}

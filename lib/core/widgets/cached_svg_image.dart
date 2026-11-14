import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Disk-cached SVG with a stable request across parent rebuilds.
class CachedSvgImage extends StatefulWidget {
  const CachedSvgImage({
    required this.url,
    required this.fallback,
    this.headers,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    super.key,
  });
  final String url;
  final Map<String, String>? headers;
  final Widget fallback;
  final double? width, height;
  final BoxFit fit;
  @override
  State<CachedSvgImage> createState() => _CachedSvgImageState();
}

class _CachedSvgImageState extends State<CachedSvgImage> {
  late Future<File> _file;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _file = DefaultCacheManager().getSingleFile(
      widget.url,
      headers: widget.headers,
    );
  }

  @override
  void didUpdateWidget(CachedSvgImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: _file,
    builder: (context, snapshot) => snapshot.hasData
        ? SvgPicture.file(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, _, _) => widget.fallback,
          )
        : widget.fallback,
  );
}

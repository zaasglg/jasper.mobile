import 'dart:async';
import '../../../../core/widgets/map_gesture_recognizer.dart';
import 'dashboard_widget_skeleton.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../storage/presentation/storage_file_screen.dart';
import 'yandex_task_map_html.dart';

class DashboardTaskMap extends StatefulWidget {
  const DashboardTaskMap({required this.tasks, this.onOpenTask, super.key});
  final ValueChanged<String>? onOpenTask;
  final List<(String, String, double, double)> tasks;
  @override
  State<DashboardTaskMap> createState() => _DashboardTaskMapState();
}

class _DashboardTaskMapState extends State<DashboardTaskMap> {
  static const _apiKey = String.fromEnvironment('YANDEX_MAPS_API_KEY');
  WebViewController? _controller;
  Timer? _timeout;
  bool _ready = false, _failed = false;
  bool get _supported =>
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);
  List<(String, String, double, double)> get _points =>
      validYandexTaskPoints(widget.tasks);
  @override
  void initState() {
    super.initState();
    if (_points.isNotEmpty && _supported && _apiKey.isNotEmpty) _load();
  }

  Future<void> _load() async {
    _timeout?.cancel();
    setState(() {
      _ready = false;
      _failed = false;
    });
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFFF6F6F8));
      await controller.addJavaScriptChannel(
        'JosparMap',
        onMessageReceived: (message) {
          if (!mounted || _controller != controller) return;
          try {
            final value = jsonDecode(message.message);
            if (value is! Map) return;
            if (value['type'] == 'ready') {
              _timeout?.cancel();
              setState(() => _ready = true);
            }
            if (value['type'] == 'error') {
              _timeout?.cancel();
              setState(() => _failed = true);
            }
            if (value['type'] == 'select') {
              final id = value['id'];
              if (id is! String || !_points.any((p) => p.$1 == id)) return;
              if (widget.onOpenTask != null) {
                widget.onOpenTask!(id);
              } else {
                context.push('/tasks/${Uri.encodeComponent(id)}');
              }
            }
          } on FormatException {
            /* Ignore malformed messages from the map document. */
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            if (request.url == 'about:blank' ||
                request.url == 'https://jospar.me/') {
              return NavigationDecision.navigate;
            }
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == 'https' &&
                (uri.host == 'yandex.ru' ||
                    uri.host.endsWith('.yandex.ru') ||
                    uri.host == 'yandex.com')) {
              await openStorageLink(uri.toString());
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true &&
                mounted &&
                _controller == controller) {
              _timeout?.cancel();
              setState(() => _failed = true);
            }
          },
        ),
      );
      await controller.loadHtmlString(
        buildYandexTaskMapHtml(_apiKey, _points),
        baseUrl: 'https://jospar.me/',
      );
      if (!mounted || _controller != controller) return;
      _timeout = Timer(const Duration(seconds: 25), () {
        if (mounted && !_ready) setState(() => _failed = true);
      });
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant DashboardTaskMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.tasks, widget.tasks)) return;
    if (_controller != null && _ready) {
      final points = _points
          .map((p) => {'id': p.$1, 'title': p.$2, 'lat': p.$3, 'lng': p.$4})
          .toList();
      _controller!
          .runJavaScript('window.josparUpdateTasks(${jsonEncode(points)});')
          .catchError((Object error) {
            if (mounted) setState(() => _failed = true);
          });
    } else if (_supported && _apiKey.isNotEmpty && _points.isNotEmpty) {
      _load();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _controller = null;
    super.dispose();
  }

  Future<void> _openExternal() async {
    if (_points.isEmpty) return;
    final point = _points.first;
    await openStorageLink(
      Uri.https('yandex.ru', '/maps/', {
        'll': '${point.$4},${point.$3}',
        'pt': _points.map((p) => '${p.$4},${p.$3},pm2blm').join('~'),
        'z': '13',
      }).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) return const SizedBox.shrink();
    final unavailable = !_supported || _apiKey.isEmpty;
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!unavailable && _controller != null)
              WebViewWidget(
                controller: _controller!,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => MapGestureRecognizer(),
                  ),
                },
              ),
            if (unavailable || _failed)
              ColoredBox(
                color: const Color(0xFFF6F6F8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 22,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Яндекс Карты',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_failed) ...[
                        const SizedBox(height: 5),
                        const Text(
                          'Не удалось загрузить карту',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Повторить'),
                        ),
                      ],
                      TextButton(
                        onPressed: _openExternal,
                        child: const Text('Открыть карту'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!unavailable && !_ready && !_failed)
              const ColoredBox(
                color: Color(0xFFF6F6F8),
                child: DashboardWidgetSkeleton(
                  kind: 'task-map',
                  showHeading: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

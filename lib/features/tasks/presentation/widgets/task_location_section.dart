import 'package:jospar/core/localization/app_translations.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../dashboard/presentation/widgets/dashboard_task_map.dart';
import '../../data/models/task_location_model.dart';
import '../cubit/task_details_cubit.dart';

class TaskLocationSection extends StatelessWidget {
  const TaskLocationSection({
    required this.location,
    required this.cubit,
    required this.enabled,
    super.key,
  });
  final TaskLocationModel? location;
  final TaskDetailsCubit cubit;
  final bool enabled;
  Future<void> _edit(BuildContext context) async {
    final result = await showModalBottomSheet<TaskLocationModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LocationEditor(initial: location),
    );
    if (result != null && context.mounted) {
      await cubit.updateLocation(result.toJson());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(LucideIcons.mapPin, size: AppIconSizes.standard),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              tr(context, 'Местоположение'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Изменить местоположение'),
            onPressed: enabled ? () => _edit(context) : null,
            icon: const Icon(LucideIcons.pencil, size: AppIconSizes.standard),
          ),
        ],
      ),
      if (location == null)
        TextButton.icon(
          onPressed: enabled ? () => _edit(context) : null,
          icon: const Icon(LucideIcons.plus, size: AppIconSizes.standard),
          label: Text(tr(context, 'Добавить местоположение')),
        ),
      if (location != null) ...[
        if (location!.latitude != null)
          DashboardTaskMap(
            tasks: [
              (
                cubit.state.task?.id ?? 'location',
                location!.address,
                location!.latitude!,
                location!.longitude!,
              ),
            ],
            onOpenTask: (_) =>
                launchUrl(location!.link, mode: LaunchMode.externalApplication),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(location!.address, style: const TextStyle(fontSize: 13)),
          trailing: const Icon(
            LucideIcons.externalLink,
            size: AppIconSizes.standard,
          ),
          onTap: () =>
              launchUrl(location!.link, mode: LaunchMode.externalApplication),
        ),
        if (enabled)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                if (await showAppConfirmation(
                      context,
                      tr(context, 'Убрать местоположение?'),
                      location!.address,
                      confirmLabel: 'Убрать',
                    ) &&
                    context.mounted) {
                  await cubit.updateLocation(null);
                }
              },
              child: Text(tr(context, 'Убрать местоположение')),
            ),
          ),
      ],
    ],
  );
}

class _LocationEditor extends StatefulWidget {
  const _LocationEditor({this.initial});
  final TaskLocationModel? initial;
  @override
  State<_LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<_LocationEditor> {
  static const _key = String.fromEnvironment('YANDEX_MAPS_API_KEY');
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _coordinates = TextEditingController(
    text: widget.initial?.latitude == null
        ? ''
        : '${widget.initial!.latitude}, ${widget.initial!.longitude}',
  );
  WebViewController? _map;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        _key.isNotEmpty &&
        [
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      _loadMap();
    }
  }

  Future<void> _loadMap() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'Location',
        onMessageReceived: (message) {
          if (!mounted) return;
          try {
            final value = TaskLocationModel.parse(jsonDecode(message.message));
            if (value == null) return;
            _address.text = value.address;
            _coordinates.text = '${value.latitude}, ${value.longitude}';
          } catch (_) {
            /* Ignore malformed map events. */
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url == 'about:blank' ||
                  request.url == 'https://jospar.me/'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      await controller.loadHtmlString(
        buildTaskLocationPickerHtml(_key, widget.initial),
        baseUrl: 'https://jospar.me/',
      );
      if (mounted) setState(() => _map = controller);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Карта недоступна. Можно указать адрес и координаты вручную.',
        );
      }
    }
  }

  void _save() {
    final text = _coordinates.text.trim();
    final parts = text.split(RegExp(r'\s*,\s*|\s+'));
    final value = TaskLocationModel(
      address: _address.text,
      latitude: text.isEmpty
          ? null
          : parts.length == 2
          ? double.tryParse(parts[0])
          : double.nan,
      longitude: text.isEmpty
          ? null
          : parts.length == 2
          ? double.tryParse(parts[1])
          : double.nan,
    );
    if (!value.valid ||
        (text.isNotEmpty &&
            (value.latitude == null || value.longitude == null))) {
      setState(
        () => _error =
            'Укажите адрес до 500 символов и корректные координаты: широта, долгота.',
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _address.dispose();
    _coordinates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Местоположение'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: tr(context, 'Адрес или название места'),
              suffixIcon: _map == null
                  ? null
                  : IconButton(
                      tooltip: tr(context, 'Найти на Яндекс Карте'),
                      onPressed: () => _map!.runJavaScript(
                        'window.searchPlace(${jsonEncode(_address.text)})',
                      ),
                      icon: const Icon(Icons.search, size: 16),
                    ),
            ),
          ),
          if (_map != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: WebViewWidget(controller: _map!),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _coordinates,
            decoration: InputDecoration(
              labelText: tr(context, 'Координаты (необязательно)'),
              hintText: '43.238949, 76.889709',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr(context, _error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(tr(context, 'Сохранить'))),
        ],
      ),
    ),
  );
}

String buildTaskLocationPickerHtml(String apiKey, TaskLocationModel? initial) {
  final source = Uri.https('api-maps.yandex.ru', '/2.1/', {
    'apikey': apiKey,
    'lang': 'ru_RU',
  });
  final point = [
    initial?.latitude ?? 43.238949,
    initial?.longitude ?? 76.889709,
  ];
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,#map{height:100%;margin:0}body{font:13px sans-serif;background:#f5f5f5}</style></head><body><div id="map">Загрузка Яндекс Карты…</div><script>
let map,marker;
function selectPlace(coords,address){if(!map)return; if(marker)map.geoObjects.remove(marker);marker=new ymaps.Placemark(coords);map.geoObjects.add(marker);Location.postMessage(JSON.stringify({address:address||coords.join(', '),latitude:coords[0],longitude:coords[1]}));}
window.searchPlace=function(query){if(!map||!query)return;ymaps.geocode(query,{results:1}).then(function(result){const place=result.geoObjects.get(0);if(!place)return;const coords=place.geometry.getCoordinates();map.setCenter(coords,16);selectPlace(coords,place.getAddressLine());});};
const script=document.createElement('script');script.src=${jsonEncode(source.toString())};script.onerror=function(){document.getElementById('map').textContent='Карта недоступна. Введите адрес вручную.';};script.onload=function(){ymaps.ready(function(){document.getElementById('map').textContent='';map=new ymaps.Map('map',{center:${jsonEncode(point)},zoom:14,controls:['zoomControl']});map.events.add('click',function(event){const coords=event.get('coords');ymaps.geocode(coords,{results:1}).then(function(result){const place=result.geoObjects.get(0);selectPlace(coords,place?place.getAddressLine():coords.join(', '));});});new ResizeObserver(function(){map.container.fitToViewport();}).observe(document.getElementById('map'));});};document.head.appendChild(script);
window.addEventListener('pagehide',function(){if(map)map.destroy();});</script></body></html>''';
}

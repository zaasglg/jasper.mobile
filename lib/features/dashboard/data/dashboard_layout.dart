import 'dart:convert';
import 'package:equatable/equatable.dart';

class DashboardWidgetDefinition {
  const DashboardWidgetDefinition(
    this.id,
    this.title,
    this.description, {
    this.duplicable = false,
    this.rows = 14,
  });
  final String id, title, description;
  final bool duplicable;
  final int rows;
  bool get available => id != 'calendar';
  static const all = [
    DashboardWidgetDefinition(
      'daily-motivation',
      'AI',
      'Фокус дня и рекомендации',
      rows: 11,
    ),
    DashboardWidgetDefinition(
      'kpi-group',
      'KPI-показатели',
      'Обзор проектов и задач',
    ),
    DashboardWidgetDefinition(
      'tasks-summary',
      'Скрам',
      'Прогресс по колонкам и эпикам',
      duplicable: true,
    ),
    DashboardWidgetDefinition(
      'activity',
      'Активность',
      'Последние события workspace',
    ),
    DashboardWidgetDefinition(
      'my-tasks',
      'Мои задачи',
      'Назначенные мне задачи',
      rows: 15,
    ),
    DashboardWidgetDefinition(
      'team',
      'Команда',
      'Участники и нагрузка',
      duplicable: true,
      rows: 15,
    ),
    DashboardWidgetDefinition('mentions', 'Упоминания', 'Упоминания и реакции'),
    DashboardWidgetDefinition(
      'calendar',
      'Ежедневник',
      'Запланированные дела',
      rows: 16,
    ),
    DashboardWidgetDefinition(
      'resource',
      'Ресурс',
      'План и факт по ресурсам',
      duplicable: true,
      rows: 20,
    ),
    DashboardWidgetDefinition(
      'task-map',
      'Карта',
      'Местоположения задач',
      duplicable: true,
      rows: 20,
    ),
  ];
  static DashboardWidgetDefinition? find(String id) {
    for (final value in all) {
      if (value.id == id) return value;
    }
    return null;
  }
}

class DashboardWidgetSlot extends Equatable {
  const DashboardWidgetSlot({
    required this.id,
    required this.instanceId,
    this.visible = true,
    this.size = 'half',
    this.height,
    this.options = const {},
  });
  final String id, instanceId, size;
  final bool visible;
  final double? height;
  final Map<String, dynamic> options;
  DashboardWidgetDefinition? get definition =>
      DashboardWidgetDefinition.find(id);
  factory DashboardWidgetSlot.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetSlot(
        id: json['id']?.toString() ?? '',
        instanceId: (json['instanceId'] ?? json['id'])?.toString() ?? '',
        visible: json['visible'] != false,
        size: ['full', 'half', 'third'].contains(json['size'])
            ? json['size'] as String
            : 'half',
        height: (json['height'] as num?)?.toDouble().clamp(180, 900),
        options: Map<String, dynamic>.from(json),
      );
  Map<String, dynamic> toJson() => {
    ...options,
    'id': id,
    'instanceId': instanceId,
    'visible': visible,
    'size': size,
    if (height != null) 'height': height,
  };
  DashboardWidgetSlot copyWith({
    String? id,
    String? instanceId,
    bool? visible,
    String? size,
    double? height,
    Map<String, dynamic>? options,
  }) => DashboardWidgetSlot(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    visible: visible ?? this.visible,
    size: size ?? this.size,
    height: height ?? this.height,
    options: options ?? this.options,
  );
  @override
  List<Object?> get props => [id, instanceId, visible, size, height, options];
}

class DashboardLayout extends Equatable {
  const DashboardLayout({
    required this.widgets,
    this.layouts = const {},
    this.extra = const {},
  });
  final List<DashboardWidgetSlot> widgets;
  final Map<String, dynamic> layouts, extra;
  static DashboardLayout defaults() => DashboardLayout(
    widgets: [
      const DashboardWidgetSlot(
        id: 'task-map',
        instanceId: 'task-map',
        visible: false,
        options: {'projectIds': []},
      ),
      const DashboardWidgetSlot(
        id: 'daily-motivation',
        instanceId: 'daily-motivation',
        size: 'full',
      ),
      const DashboardWidgetSlot(
        id: 'kpi-group',
        instanceId: 'kpi-group',
        size: 'full',
      ),
      const DashboardWidgetSlot(
        id: 'tasks-summary',
        instanceId: 'tasks-summary',
        options: {'projectIds': [], 'mode': 'column'},
      ),
      const DashboardWidgetSlot(id: 'activity', instanceId: 'activity'),
      const DashboardWidgetSlot(id: 'my-tasks', instanceId: 'my-tasks'),
      const DashboardWidgetSlot(id: 'mentions', instanceId: 'mentions'),
      const DashboardWidgetSlot(
        id: 'team',
        instanceId: 'team',
        size: 'full',
        visible: false,
        options: {'teamProjectId': 'all'},
      ),
      const DashboardWidgetSlot(id: 'calendar', instanceId: 'calendar'),
      const DashboardWidgetSlot(
        id: 'resource',
        instanceId: 'resource',
        size: 'third',
        options: {
          'resourceProjectId': 'all',
          'resourceFilterType': 'projects',
          'resourceNamesByProject': {},
          'resourceModeByProject': {},
          'resourceLabelKeys': [],
          'resourceEpicIds': [],
          'resourceNames': [],
        },
      ),
    ],
  );
  factory DashboardLayout.fromJson(Map<String, dynamic> json) =>
      DashboardLayout.parse(json);
  static DashboardLayout parse(dynamic value) {
    if (value is String) {
      // Workspaces without saved settings can return an empty HTTP 200 body.
      if (value.trim().isEmpty) return defaults();
      value = jsonDecode(value);
    }
    if (value == null) return defaults();
    if (value is Map && value.containsKey('layout')) {
      return parse(value['layout']);
    }
    final raw = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final values = value is List ? value : raw['widgets'];
    if (values is! List) {
      throw const FormatException('Не удалось прочитать настройки дашборда');
    }
    final ids = <String>{};
    final slots = values
        .whereType<Map>()
        .map((e) => DashboardWidgetSlot.fromJson(Map<String, dynamic>.from(e)))
        .where(
          (e) =>
              e.id.isNotEmpty &&
              e.instanceId.isNotEmpty &&
              ids.add(e.instanceId),
        )
        .toList();
    for (final slot in defaults().widgets) {
      if (slot.definition?.duplicable != true &&
          !slots.any((e) => e.id == slot.id)) {
        slots.add(slot);
      }
    }
    return DashboardLayout(
      widgets: slots,
      layouts: raw['layouts'] is Map
          ? Map<String, dynamic>.from(raw['layouts'] as Map)
          : {},
      extra: raw,
    );
  }

  /// Mobile order is the web's single-column sm layout; desktop coordinates survive.
  List<DashboardWidgetSlot> get ordered {
    final positions = <String, num>{};
    final sm = layouts['sm'];
    if (sm is List) {
      for (final row in sm.whereType<Map>()) {
        if (row['y'] is num) positions[row['i'].toString()] = row['y'] as num;
      }
    }
    final order = {
      for (var i = 0; i < widgets.length; i++) widgets[i].instanceId: i,
    };
    return [...widgets]..sort((a, b) {
      final ay = positions[a.instanceId], by = positions[b.instanceId];
      if (ay == null && by == null) {
        return order[a.instanceId]!.compareTo(order[b.instanceId]!);
      }
      if (ay == null) return 1;
      if (by == null) return -1;
      final result = ay.compareTo(by);
      return result != 0
          ? result
          : order[a.instanceId]!.compareTo(order[b.instanceId]!);
    });
  }

  DashboardLayout withWidgets(
    List<DashboardWidgetSlot> next, {
    Set<String> resized = const {},
  }) {
    final grid = Map<String, dynamic>.from(layouts);
    final existingSm = {
      for (final row in (grid['sm'] as List? ?? []).whereType<Map>())
        row['i'].toString(): Map<String, dynamic>.from(row),
    };
    var y = 0;
    final sm = <Map<String, dynamic>>[];
    for (final slot in [
      ...next.where((e) => e.visible),
      ...next.where((e) => !e.visible),
    ]) {
      final previous = existingSm[slot.instanceId] ?? {};
      final minH = slot.definition?.rows ?? 14;
      final h = resized.contains(slot.instanceId) || previous['h'] is! num
          ? (slot.height == null
                ? minH
                : ((slot.height! + 16) / 24).ceil().clamp(minH, 38))
          : (previous['h'] as num).toInt();
      sm.add({
        ...previous,
        'i': slot.instanceId,
        'x': 0,
        'y': y,
        'w': 1,
        'h': h,
        'minW': 1,
        'minH': minH,
        'maxH': 38,
      });
      if (slot.visible) y += h;
    }
    grid['sm'] = sm;
    final liveIds = next.map((e) => e.instanceId).toSet();
    for (final breakpoint in ['lg', 'md']) {
      final cols = breakpoint == 'lg' ? 12 : 8;
      int width(DashboardWidgetSlot slot) => slot.size == 'full'
          ? cols
          : slot.size == 'third' && slot.id != 'kpi-group'
          ? (cols / 3).ceil()
          : cols ~/ 2;
      int height(DashboardWidgetSlot slot) => slot.height == null
          ? slot.definition?.rows ?? 14
          : ((slot.height! + 16) / 24).ceil().clamp(
              slot.definition?.rows ?? 14,
              38,
            );
      var rows = (grid[breakpoint] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => liveIds.contains(e['i']))
          .toList();
      if (rows.isEmpty) {
        var x = 0, y = 0, rowHeight = 0;
        for (final slot in [
          ...next.where((e) => e.visible),
          ...next.where((e) => !e.visible),
        ]) {
          final w = width(slot), h = height(slot);
          if (x + w > cols) {
            y += rowHeight;
            x = 0;
            rowHeight = 0;
          }
          rows.add({
            'i': slot.instanceId,
            'x': x,
            'y': y,
            'w': w,
            'h': h,
            'minW': slot.id == 'kpi-group' ? cols ~/ 2 : (cols / 3).ceil(),
            'minH': slot.definition?.rows ?? 14,
            'maxH': 38,
          });
          x += w;
          if (h > rowHeight) rowHeight = h;
          if (x >= cols) {
            y += rowHeight;
            x = 0;
            rowHeight = 0;
          }
        }
      } else {
        var bottom = rows.fold<int>(0, (value, e) {
          final end =
              ((e['y'] as num?)?.toInt() ?? 0) +
              ((e['h'] as num?)?.toInt() ?? 14);
          return end > value ? end : value;
        });
        for (final slot in next) {
          final index = rows.indexWhere((e) => e['i'] == slot.instanceId);
          final previous = widgets
              .where((e) => e.instanceId == slot.instanceId)
              .firstOrNull;
          final sizeChanged = previous != null && previous.size != slot.size;
          if (index >= 0 &&
              !resized.contains(slot.instanceId) &&
              !sizeChanged) {
            continue;
          }
          final h = height(slot);
          final row = <String, dynamic>{
            if (index >= 0) ...rows[index],
            'i': slot.instanceId,
            'x': 0,
            'y': bottom,
            'w': width(slot),
            'h': h,
            'minW': slot.id == 'kpi-group' ? cols ~/ 2 : (cols / 3).ceil(),
            'minH': slot.definition?.rows ?? 14,
            'maxH': 38,
          };
          if (index >= 0) {
            rows[index] = row;
          } else {
            rows.add(row);
          }
          bottom += h;
        }
      }
      grid[breakpoint] = rows;
    }
    return copyWith(widgets: next, layouts: grid);
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'version': 2,
    'widgets': widgets.map((e) => e.toJson()).toList(),
    'layouts': layouts,
  };
  DashboardLayout copyWith({
    List<DashboardWidgetSlot>? widgets,
    Map<String, dynamic>? layouts,
    Map<String, dynamic>? extra,
  }) => DashboardLayout(
    widgets: widgets ?? this.widgets,
    layouts: layouts ?? this.layouts,
    extra: extra ?? this.extra,
  );
  @override
  List<Object?> get props => [widgets, layouts, extra];
}

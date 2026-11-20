import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_layout.dart';
import 'dashboard_widget_slot_dto.dart';

class DashboardLayoutDto extends Equatable {
  const DashboardLayoutDto({
    required this.widgets,
    this.layouts = const {},
    this.unknownExtra = const {},
  });
  final List<DashboardWidgetSlotDto> widgets;
  final Map<String, dynamic> layouts, unknownExtra;
  static DashboardLayoutDto defaults() =>
      DashboardLayoutDto.fromEntity(DashboardLayout.defaults());
  factory DashboardLayoutDto.fromJson(Map<String, dynamic> json) =>
      DashboardLayoutDto.parse(json);
  static DashboardLayoutDto parse(dynamic value) {
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
      // Match the web client's parseSavedConfig fallback for legacy configs.
      return defaults();
    }
    final ids = <String>{};
    final slots = values
        .whereType<Map>()
        .map(
          (e) => DashboardWidgetSlotDto.fromJson(Map<String, dynamic>.from(e)),
        )
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
    return DashboardLayoutDto(
      widgets: slots,
      layouts: raw['layouts'] is Map
          ? Map<String, dynamic>.from(raw['layouts'] as Map)
          : {},
      unknownExtra: {
        for (final entry in raw.entries)
          if (!['version', 'widgets', 'layouts'].contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    ...unknownExtra,
    'version': 2,
    'widgets': widgets.map((e) => e.toJson()).toList(),
    'layouts': layouts,
  };
  DashboardLayoutDto copyWith({
    List<DashboardWidgetSlotDto>? widgets,
    Map<String, dynamic>? layouts,
    Map<String, dynamic>? unknownExtra,
  }) => DashboardLayoutDto(
    widgets: widgets ?? this.widgets,
    layouts: layouts ?? this.layouts,
    unknownExtra: unknownExtra ?? this.unknownExtra,
  );
  factory DashboardLayoutDto.fromEntity(DashboardLayout entity) =>
      DashboardLayoutDto(
        widgets: entity.widgets.map(DashboardWidgetSlotDto.fromEntity).toList(),
        layouts: entity.layouts,
        unknownExtra: entity.unknownExtra,
      );
  DashboardLayout toEntity() => DashboardLayout(
    widgets: widgets.map((e) => e.toEntity()).toList(),
    layouts: layouts,
    unknownExtra: unknownExtra,
  );
  @override
  List<Object?> get props => [widgets, layouts, unknownExtra];
}

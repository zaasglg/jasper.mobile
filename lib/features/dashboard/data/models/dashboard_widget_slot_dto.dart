import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_widget_slot.dart';
import '../../domain/entities/dashboard_widget_definition.dart';
import 'dashboard_widget_options_dto.dart';

class DashboardWidgetSlotDto extends Equatable {
  const DashboardWidgetSlotDto({
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
  factory DashboardWidgetSlotDto.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetSlotDto(
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
  DashboardWidgetSlotDto copyWith({
    String? id,
    String? instanceId,
    bool? visible,
    String? size,
    double? height,
    Map<String, dynamic>? options,
  }) => DashboardWidgetSlotDto(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    visible: visible ?? this.visible,
    size: size ?? this.size,
    height: height ?? this.height,
    options: options ?? this.options,
  );
  factory DashboardWidgetSlotDto.fromEntity(DashboardWidgetSlot entity) =>
      DashboardWidgetSlotDto(
        id: entity.id,
        instanceId: entity.instanceId,
        visible: entity.visible,
        size: entity.size,
        height: entity.height,
        options: DashboardWidgetOptionsDto.fromEntity(entity.options).toJson(),
      );
  DashboardWidgetSlot toEntity() => DashboardWidgetSlot(
    id: id,
    instanceId: instanceId,
    visible: visible,
    size: size,
    height: height,
    options: DashboardWidgetOptionsDto.fromJson({
      for (final entry in options.entries)
        if (![
          'id',
          'instanceId',
          'visible',
          'size',
          'height',
        ].contains(entry.key))
          entry.key: entry.value,
    }).toEntity(),
  );
  @override
  List<Object?> get props => [id, instanceId, visible, size, height, options];
}

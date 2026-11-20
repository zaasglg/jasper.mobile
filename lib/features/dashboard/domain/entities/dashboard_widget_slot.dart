import 'package:equatable/equatable.dart';
import 'dashboard_widget_options.dart';
import 'dashboard_widget_definition.dart';

class DashboardWidgetSlot extends Equatable {
  const DashboardWidgetSlot({
    required this.id,
    required this.instanceId,
    this.visible = true,
    this.size = 'half',
    this.height,
    this.options = const DashboardWidgetOptions(),
  });
  final String id, instanceId, size;
  final bool visible;
  final double? height;
  final DashboardWidgetOptions options;
  DashboardWidgetDefinition? get definition =>
      DashboardWidgetDefinition.find(id);
  DashboardWidgetSlot copyWith({
    String? id,
    String? instanceId,
    bool? visible,
    String? size,
    double? height,
    DashboardWidgetOptions? options,
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

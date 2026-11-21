import '../../domain/entities/kanban_column_model.dart';
import 'package:equatable/equatable.dart';

class KanbanColumnDto extends Equatable {
  const KanbanColumnDto({
    required this.id,
    required this.name,
    required this.statusMap,
    this.projectId = '',
    this.color,
    this.wip,
    this.order = 0,
    this.archived = false,
  });

  factory KanbanColumnDto.fromJson(Map<String, dynamic> json) {
    return KanbanColumnDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      statusMap:
          json['statusMap']?.toString() ?? json['status_map']?.toString() ?? '',
      projectId:
          json['projectId']?.toString() ?? json['project_id']?.toString() ?? '',
      color: _optionalString(json['color']),
      wip: _parseInt(json['wip']),
      order: _parseInt(json['order']) ?? 0,
      archived: _parseBool(json['archived']),
    );
  }

  final String id;
  final String name;
  final String statusMap;
  final String projectId;
  final String? color;
  final int? wip;
  final int order;
  final bool archived;

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'statusMap': statusMap,
    'projectId': projectId,
    if (color != null) 'color': color,
    'wip': wip,
    'order': order,
    'archived': archived,
  };

  KanbanColumnDto copyWith({
    String? id,
    String? name,
    String? statusMap,
    String? projectId,
    String? color,
    int? wip,
    int? order,
    bool? archived,
  }) {
    return KanbanColumnDto(
      id: id ?? this.id,
      name: name ?? this.name,
      statusMap: statusMap ?? this.statusMap,
      projectId: projectId ?? this.projectId,
      color: color ?? this.color,
      wip: wip ?? this.wip,
      order: order ?? this.order,
      archived: archived ?? this.archived,
    );
  }

  factory KanbanColumnDto.fromEntity(KanbanColumnModel entity) =>
      KanbanColumnDto(
        id: entity.id,
        name: entity.name,
        statusMap: entity.statusMap,
        projectId: entity.projectId,
        color: entity.color,
        wip: entity.wip,
        order: entity.order,
        archived: entity.archived,
      );
  KanbanColumnModel toEntity() => KanbanColumnModel(
    id: id,
    name: name,
    statusMap: statusMap,
    projectId: projectId,
    color: color,
    wip: wip,
    order: order,
    archived: archived,
  );
  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    statusMap,
    projectId,
    color,
    wip,
    order,
    archived,
  ];
}

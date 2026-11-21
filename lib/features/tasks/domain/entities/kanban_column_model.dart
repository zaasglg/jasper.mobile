import 'package:equatable/equatable.dart';

class KanbanColumnModel extends Equatable {
  const KanbanColumnModel({
    required this.id,
    required this.name,
    required this.statusMap,
    this.projectId = '',
    this.color,
    this.wip,
    this.order = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final String statusMap;
  final String projectId;
  final String? color;
  final int? wip;
  final int order;
  final bool archived;

  KanbanColumnModel copyWith({
    String? id,
    String? name,
    String? statusMap,
    String? projectId,
    String? color,
    int? wip,
    int? order,
    bool? archived,
  }) {
    return KanbanColumnModel(
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

import 'package:equatable/equatable.dart';

class InboxTaskModel extends Equatable {
  const InboxTaskModel({
    required this.id,
    required this.title,
    this.displayId = '',
    this.description,
    this.completed = false,
    this.archived = false,
    this.order = 0,
    this.createdAt,
    this.isLocalOnly = false,
  });

  factory InboxTaskModel.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase();
    return InboxTaskModel(
      id: (json['id'] ?? json['taskId'] ?? json['task_id'])?.toString() ?? '',
      displayId:
          (json['displayId'] ?? json['display_id'] ?? json['key'])
              ?.toString() ??
          '',
      title: _firstText(json, const <String>[
        'title',
        'name',
        'subject',
        'content',
        'text',
      ]),
      description: _optionalText(
        json['description'] ?? json['detail'] ?? json['body'],
      ),
      completed:
          _parseBool(json['completed'] ?? json['isCompleted']) ||
          status == 'DONE' ||
          json['completedAt'] != null ||
          json['completed_at'] != null,
      archived: _parseBool(json['archived'] ?? json['isArchived']),
      order: _parseInt(json['order'] ?? json['sort'] ?? json['position']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  final String id;
  final String displayId;
  final String title;
  final String? description;
  final bool completed;
  final bool archived;
  final int order;
  final DateTime? createdAt;
  final bool isLocalOnly;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'displayId': displayId,
    'title': title,
    if (description != null) 'description': description,
    'completed': completed,
    'archived': archived,
    'order': order,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
  };

  InboxTaskModel copyWith({
    String? id,
    String? displayId,
    String? title,
    String? description,
    bool? completed,
    bool? archived,
    int? order,
    DateTime? createdAt,
    bool? isLocalOnly,
  }) {
    return InboxTaskModel(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      archived: archived ?? this.archived,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final text = _optionalText(json[key]);
      if (text != null) return text;
    }
    return '';
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const <String>{
      'true',
      '1',
      'yes',
    }.contains(value?.toString().toLowerCase());
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    displayId,
    title,
    description,
    completed,
    archived,
    order,
    createdAt,
    isLocalOnly,
  ];
}

import 'package:equatable/equatable.dart';

/// A selected upload or the server's analysis report (without file contents).
class AssistantAttachment extends Equatable {
  const AssistantAttachment({
    required this.name,
    required this.mimeType,
    required this.size,
    this.dataUrl,
    this.status,
    this.analysisMode,
    this.reason,
    this.truncated = false,
  });
  final String name, mimeType;
  final int size;
  final String? dataUrl, status, analysisMode, reason;
  final bool truncated;
  bool get isImage =>
      dataUrl != null &&
      const [
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
      ].contains(mimeType);
  factory AssistantAttachment.fromJson(Map<String, dynamic> json) =>
      AssistantAttachment(
        name: json['name'] is String ? json['name'] as String : 'Файл',
        mimeType: json['mimeType'] is String
            ? json['mimeType'] as String
            : 'application/octet-stream',
        size: json['size'] is num ? (json['size'] as num).toInt() : 0,
        dataUrl: json['dataUrl'] is String ? json['dataUrl'] as String : null,
        status: json['status'] is String ? json['status'] as String : null,
        analysisMode: json['analysisMode'] is String
            ? json['analysisMode'] as String
            : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        truncated: json['truncated'] == true,
      );
  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'size': size,
    'dataUrl': ?dataUrl,
    'status': ?status,
    'analysisMode': ?analysisMode,
    'reason': ?reason,
    if (truncated) 'truncated': true,
  };
  Map<String, dynamic> toUploadJson() => {
    'name': name,
    'mimeType': mimeType,
    'size': size,
    'dataUrl': dataUrl,
  };
  AssistantAttachment copyWith({
    String? name,
    String? mimeType,
    int? size,
    String? dataUrl,
    String? status,
    String? analysisMode,
    String? reason,
    bool? truncated,
  }) => AssistantAttachment(
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    dataUrl: dataUrl ?? this.dataUrl,
    status: status ?? this.status,
    analysisMode: analysisMode ?? this.analysisMode,
    reason: reason ?? this.reason,
    truncated: truncated ?? this.truncated,
  );
  static List<AssistantAttachment> parseList(dynamic raw) => raw is List
      ? raw
            .whereType<Map>()
            .map(
              (e) => AssistantAttachment.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
      : const [];
  @override
  List<Object?> get props => [
    name,
    mimeType,
    size,
    dataUrl,
    status,
    analysisMode,
    reason,
    truncated,
  ];
}

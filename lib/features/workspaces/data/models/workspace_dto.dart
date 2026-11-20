import '../../../../core/network/api_constants.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/workspace_model.dart';

class WorkspaceDto extends Equatable {
  const WorkspaceDto({
    required this.id,
    required this.name,
    this.color,
    this.logoUrl,
  });

  factory WorkspaceDto.fromJson(Map<String, dynamic> json) {
    final rawLogoUrl = _readLogoUrl(json);

    return WorkspaceDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      logoUrl: rawLogoUrl is String && rawLogoUrl.trim().isNotEmpty
          ? _resolveLogoUrl(rawLogoUrl.trim())
          : null,
    );
  }

  factory WorkspaceDto.fromEntity(WorkspaceModel entity) => WorkspaceDto(
    id: entity.id,
    name: entity.name,
    color: entity.color,
    logoUrl: entity.logoUrl,
  );

  WorkspaceModel toEntity() =>
      WorkspaceModel(id: id, name: name, color: color, logoUrl: logoUrl);

  final String id;
  final String name;
  final String? color;
  final String? logoUrl;

  static String? _readLogoUrl(Map<String, dynamic> json) {
    final directValue =
        json['logoUrl'] ?? json['logo_url'] ?? json['logo'] ?? json['imageUrl'];
    if (directValue is String) return directValue;
    if (directValue is Map) {
      final logo = Map<String, dynamic>.from(directValue);
      final nestedValue = logo['url'] ?? logo['src'] ?? logo['path'];
      if (nestedValue is String) return nestedValue;
    }

    final brandingValue = json['branding'];
    if (brandingValue is Map) {
      final branding = Map<String, dynamic>.from(brandingValue);
      final nestedValue = branding['logoUrl'] ?? branding['logo_url'];
      if (nestedValue is String) return nestedValue;
    }
    return null;
  }

  static String _resolveLogoUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return ApiConstants.origin.resolve(value).toString();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': color,
    'logoUrl': logoUrl,
  };

  WorkspaceDto copyWith({
    String? id,
    String? name,
    String? color,
    String? logoUrl,
  }) {
    return WorkspaceDto(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, color, logoUrl];
}

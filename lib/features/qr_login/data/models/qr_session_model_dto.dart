import '../../domain/entities/qr_session_model.dart';
import 'package:equatable/equatable.dart';

class QrSessionModelDto extends Equatable {
  const QrSessionModelDto({
    required this.id,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory QrSessionModelDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue?.toString();
    final createdValue = json['createdAt'] ?? json['created_at'];
    final createdAt = DateTime.tryParse(createdValue?.toString() ?? '');
    final activeValue =
        json['lastActiveAt'] ??
        json['lastUsedAt'] ??
        json['updatedAt'] ??
        createdValue;
    final lastActiveAt = DateTime.tryParse(activeValue?.toString() ?? '');
    if (id == null || id.isEmpty || createdAt == null || lastActiveAt == null) {
      throw const FormatException('Некорректный QR-сеанс');
    }
    return QrSessionModelDto(
      id: id,
      deviceInfo:
          (json['deviceInfo'] ?? json['userAgent'] ?? json['device'])
              ?.toString() ??
          'Неизвестное устройство',
      ipAddress: (json['ipAddress'] ?? json['ip'])?.toString() ?? '—',
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
    );
  }

  factory QrSessionModelDto.fromEntity(QrSessionModel entity) =>
      QrSessionModelDto(
        id: entity.id,
        deviceInfo: entity.deviceInfo,
        ipAddress: entity.ipAddress,
        createdAt: entity.createdAt,
        lastActiveAt: entity.lastActiveAt,
      );
  QrSessionModel toEntity() => QrSessionModel(
    id: id,
    deviceInfo: deviceInfo,
    ipAddress: ipAddress,
    createdAt: createdAt,
    lastActiveAt: lastActiveAt,
  );
  final String id;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'deviceInfo': deviceInfo,
    'ipAddress': ipAddress,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
  };

  QrSessionModelDto copyWith({
    String? id,
    String? deviceInfo,
    String? ipAddress,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) => QrSessionModelDto(
    id: id ?? this.id,
    deviceInfo: deviceInfo ?? this.deviceInfo,
    ipAddress: ipAddress ?? this.ipAddress,
    createdAt: createdAt ?? this.createdAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    deviceInfo,
    ipAddress,
    createdAt,
    lastActiveAt,
  ];
}

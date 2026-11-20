import '../../domain/entities/qr_login_details.dart';
import 'package:equatable/equatable.dart';

class QrLoginDetailsDto extends Equatable {
  const QrLoginDetailsDto({
    required this.status,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.expiresAt,
  });

  factory QrLoginDetailsDto.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (json['status'] != 'scanned' || createdAt == null || expiresAt == null) {
      throw const FormatException('Некорректный ответ сервера');
    }
    return QrLoginDetailsDto(
      status: 'scanned',
      deviceInfo: json['deviceInfo'] as String? ?? 'Неизвестное устройство',
      ipAddress: json['ipAddress'] as String? ?? '—',
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  factory QrLoginDetailsDto.fromEntity(QrLoginDetails entity) =>
      QrLoginDetailsDto(
        status: entity.status,
        deviceInfo: entity.deviceInfo,
        ipAddress: entity.ipAddress,
        createdAt: entity.createdAt,
        expiresAt: entity.expiresAt,
      );
  QrLoginDetails toEntity() => QrLoginDetails(
    status: status,
    deviceInfo: deviceInfo,
    ipAddress: ipAddress,
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
  final String status;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status,
    'deviceInfo': deviceInfo,
    'ipAddress': ipAddress,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  QrLoginDetailsDto copyWith({
    String? status,
    String? deviceInfo,
    String? ipAddress,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) => QrLoginDetailsDto(
    status: status ?? this.status,
    deviceInfo: deviceInfo ?? this.deviceInfo,
    ipAddress: ipAddress ?? this.ipAddress,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    deviceInfo,
    ipAddress,
    createdAt,
    expiresAt,
  ];
}

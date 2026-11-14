import 'package:equatable/equatable.dart';

class QrLoginDetails extends Equatable {
  const QrLoginDetails({
    required this.status,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.expiresAt,
  });

  factory QrLoginDetails.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (json['status'] != 'scanned' || createdAt == null || expiresAt == null) {
      throw const FormatException('Некорректный ответ сервера');
    }
    return QrLoginDetails(
      status: 'scanned',
      deviceInfo: json['deviceInfo'] as String? ?? 'Неизвестное устройство',
      ipAddress: json['ipAddress'] as String? ?? '—',
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

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

  QrLoginDetails copyWith({
    String? status,
    String? deviceInfo,
    String? ipAddress,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) => QrLoginDetails(
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

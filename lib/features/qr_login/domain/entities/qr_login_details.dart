import 'package:equatable/equatable.dart';

class QrLoginDetails extends Equatable {
  const QrLoginDetails({
    required this.status,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.expiresAt,
  });

  final String status;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime expiresAt;

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

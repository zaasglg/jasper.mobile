import 'package:equatable/equatable.dart';

class QrSessionModel extends Equatable {
  const QrSessionModel({
    required this.id,
    required this.deviceInfo,
    required this.ipAddress,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String id;
  final String deviceInfo;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  QrSessionModel copyWith({
    String? id,
    String? deviceInfo,
    String? ipAddress,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) => QrSessionModel(
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

import '../../domain/entities/qr_login_payload.dart';
import 'dart:convert';

import 'package:equatable/equatable.dart';

class QrLoginPayloadDto extends Equatable {
  const QrLoginPayloadDto({required this.id, required this.scanToken});

  factory QrLoginPayloadDto.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'orbita:qr-login' || json['version'] != 1) {
      throw const FormatException('Некорректный QR-код');
    }
    final id = json['id'];
    final scanToken = json['scanToken'];
    final safe = RegExp(r'^[A-Za-z0-9_-]+$');
    if (id is! String ||
        id.length != 32 ||
        !safe.hasMatch(id) ||
        scanToken is! String ||
        scanToken.length != 43 ||
        !safe.hasMatch(scanToken)) {
      throw const FormatException('Некорректный QR-код');
    }
    return QrLoginPayloadDto(id: id, scanToken: scanToken);
  }

  factory QrLoginPayloadDto.parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      return QrLoginPayloadDto.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      throw const FormatException('Некорректный QR-код');
    }
  }

  factory QrLoginPayloadDto.fromEntity(QrLoginPayload entity) =>
      QrLoginPayloadDto(id: entity.id, scanToken: entity.scanToken);
  QrLoginPayload toEntity() => QrLoginPayload(id: id, scanToken: scanToken);
  final String id;
  final String scanToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'orbita:qr-login',
    'version': 1,
    'id': id,
    'scanToken': scanToken,
  };

  QrLoginPayloadDto copyWith({String? id, String? scanToken}) =>
      QrLoginPayloadDto(
        id: id ?? this.id,
        scanToken: scanToken ?? this.scanToken,
      );

  @override
  List<Object?> get props => <Object?>[id, scanToken];
}

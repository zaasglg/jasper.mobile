import 'entities/qr_login_details.dart';
import 'entities/qr_login_payload.dart';
import 'entities/qr_session_model.dart';

abstract interface class QrLoginRepository {
  QrLoginPayload parsePayload(String raw);
  Future<QrLoginDetails> scan(QrLoginPayload payload);
  Future<void> approve(QrLoginPayload payload);
  Future<void> reject(QrLoginPayload payload);
}

abstract interface class QrSessionsRepository {
  Future<List<QrSessionModel>> getSessions();
  Future<void> revokeSession(String sessionId);
}

class QrLoginException implements Exception {
  const QrLoginException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

import 'package:dio/dio.dart';

import '../domain/qr_login_repository.dart';
import 'models/qr_login_details.dart';
import 'models/qr_login_payload.dart';
import 'models/qr_session_model.dart';

class QrLoginRepositoryImpl implements QrLoginRepository, QrSessionsRepository {
  const QrLoginRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<QrLoginDetails> scan(QrLoginPayload payload) async {
    try {
      final response = await _dio.post<dynamic>(
        'auth/qr/${payload.id}/scan',
        data: <String, dynamic>{'scanToken': payload.scanToken},
      );
      return QrLoginDetails.fromJson(_map(response.data));
    } on DioException catch (error) {
      throw _exception(error);
    } on FormatException {
      throw const QrLoginException('Сервер вернул некорректный ответ.');
    }
  }

  @override
  Future<void> approve(QrLoginPayload payload) =>
      _action(payload, 'approve', 'approved');

  @override
  Future<void> reject(QrLoginPayload payload) =>
      _action(payload, 'reject', 'rejected');

  @override
  Future<List<QrSessionModel>> getSessions() async {
    try {
      final response = await _dio.get<dynamic>('auth/sessions');
      final data = response.data;
      final items = data is List
          ? data
          : data is Map
          ? data['sessions']
          : null;
      if (items is! List) throw const FormatException();
      return items
          .map(
            (item) =>
                QrSessionModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw _exception(error);
    } on FormatException {
      throw const QrLoginException('Сервер вернул некорректный ответ.');
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      await _dio.delete<dynamic>(
        'auth/sessions/${Uri.encodeComponent(sessionId)}',
      );
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  Future<void> _action(
    QrLoginPayload payload,
    String action,
    String expected,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        'auth/qr/${payload.id}/$action',
        data: <String, dynamic>{'scanToken': payload.scanToken},
      );
      if (_map(response.data)['status'] != expected) {
        throw const FormatException();
      }
    } on DioException catch (error) {
      throw _exception(error);
    } on FormatException {
      throw const QrLoginException('Сервер вернул некорректный ответ.');
    }
  }

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException();
  }

  QrLoginException _exception(DioException error) {
    final code = error.response?.statusCode;
    return QrLoginException(switch (code) {
      400 => 'Некорректный QR-код.',
      401 => 'Сессия недействительна. Войдите снова и отсканируйте новый QR.',
      409 => 'QR-код уже изменён или использован. Обновите его на компьютере.',
      410 => 'QR-код истёк. Обновите его на компьютере.',
      429 => 'Слишком много запросов. Повторите через минуту.',
      _ => 'Не удалось связаться с сервером. Проверьте интернет и повторите.',
    }, statusCode: code);
  }
}

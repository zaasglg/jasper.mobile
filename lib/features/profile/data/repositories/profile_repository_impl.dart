import 'package:dio/dio.dart';

import '../../domain/repositories/profile_repository.dart';
import '../models/user_profile.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserProfile> getCurrentUser() async {
    try {
      final response = await _dio.get<dynamic>('users/me');
      final json = _unwrapPayload(response.data);
      return UserProfile.fromJson(json);
    } on DioException catch (error) {
      throw ProfileException(_messageForDioError(error));
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw const ProfileException('Не удалось загрузить данные профиля.');
    }
  }

  Map<String, dynamic> _unwrapPayload(dynamic data) {
    if (data is! Map) {
      throw const ProfileException(
        'Сервер вернул некорректные данные профиля.',
      );
    }

    final payload = Map<String, dynamic>.from(data);
    final nestedData = payload['data'];
    if (nestedData is Map) return Map<String, dynamic>.from(nestedData);
    return payload;
  }

  String _messageForDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Сервер не отвечает. Попробуйте ещё раз.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          return 'Сессия истекла. Войдите снова.';
        }
        return 'Не удалось загрузить данные профиля.';
      case DioExceptionType.cancel:
        return 'Запрос был отменён.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Не удалось подключиться к серверу.';
    }
  }
}

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

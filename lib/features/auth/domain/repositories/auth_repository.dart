import '../../data/models/login_request.dart';

abstract interface class AuthRepository {
  Future<String> login(LoginRequest request);

  Future<void> logout();
}

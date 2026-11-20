import '../entities/login_request.dart';

abstract interface class GoogleLoginRepository {
  Future<String?> loginWithGoogle();
}

abstract interface class AppleLoginRepository {
  Future<String?> loginWithApple();
}

abstract interface class AuthRepository {
  Future<String> login(LoginRequest request);

  Future<void> logout();
}

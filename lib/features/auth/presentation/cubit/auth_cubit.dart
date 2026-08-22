import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/login_request.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;

  Future<void> login({required String email, required String password}) async {
    if (state is AuthLoading) return;

    final normalizedEmail = email.trim();
    if (!_isValidEmail(normalizedEmail)) {
      emit(const AuthFailure('Введите корректный email.'));
      return;
    }
    if (password.isEmpty) {
      emit(const AuthFailure('Введите пароль.'));
      return;
    }

    emit(const AuthLoading());
    try {
      final token = await _repository.login(
        LoginRequest(email: normalizedEmail, password: password),
      );
      emit(AuthAuthenticated(token));
    } on AuthException catch (error) {
      emit(AuthFailure(error.message));
    } catch (_) {
      emit(const AuthFailure('Не удалось выполнить вход. Попробуйте ещё раз.'));
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

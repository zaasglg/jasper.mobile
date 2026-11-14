import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:jospar/features/auth/data/models/login_request.dart';
import 'package:jospar/features/auth/domain/repositories/auth_repository.dart';
import 'package:jospar/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:jospar/features/auth/presentation/cubit/auth_state.dart';

void main() {
  group('LoginRequest', () {
    test('serializes and copies explicitly', () {
      const request = LoginRequest(email: 'user@jospar.me', password: 'secret');

      expect(request.toJson(), <String, dynamic>{
        'email': 'user@jospar.me',
        'password': 'secret',
      });
      expect(LoginRequest.fromJson(request.toJson()), request);
      expect(request.copyWith(email: 'new@jospar.me').password, 'secret');
    });
  });

  group('AuthCubit', () {
    for (final fails in [false, true]) {
      test(
        'closed login ignores a delayed response (failure: $fails)',
        () async {
          final pending = Completer<String>();
          final repository = _FakeAuthRepository()
            ..pendingLogin = pending.future;
          final cubit = AuthCubit(repository);
          final generation = authSession.generation;
          final operation = cubit.login(
            email: 'user@jospar.me',
            password: 'secret',
          );
          final completed = expectLater(operation, completes);
          await cubit.close();
          if (fails) {
            pending.completeError(const AuthException('Login failed'));
          } else {
            pending.complete('late-token');
          }
          await completed;
          expect(authSession.generation, generation);
        },
      );

      test(
        'closed logout handles a delayed response (failure: $fails)',
        () async {
          final pending = Completer<void>();
          final repository = _FakeAuthRepository()
            ..pendingLogout = pending.future;
          final cubit = AuthCubit(repository);
          final operation = cubit.logout();
          final completed = expectLater(operation, completes);
          await cubit.close();
          if (fails) {
            pending.completeError(const AuthException('Logout failed'));
          } else {
            pending.complete();
          }
          await completed;
          if (!fails) expect(authSession.requiresLogin, isTrue);
        },
      );
    }
    test(
      'Google login authenticates and cancellation resets loading',
      () async {
        final repository = _FakeAuthRepository();
        final cubit = AuthCubit(repository);
        await cubit.loginWithGoogle();
        expect(cubit.state, const AuthAuthenticated('google-token'));
        repository.googleToken = null;
        await cubit.loginWithGoogle();
        expect(cubit.state, const AuthInitial());
        await cubit.close();
      },
    );
    test('Apple login authenticates and cancellation resets loading', () async {
      final repository = _FakeAuthRepository();
      final cubit = AuthCubit(repository);
      await cubit.loginWithApple();
      expect(cubit.state, const AuthAuthenticated('apple-token'));
      repository.appleToken = null;
      await cubit.loginWithApple();
      expect(cubit.state, const AuthInitial());
      await cubit.close();
    });
    test('rejects an invalid email without calling repository', () async {
      final repository = _FakeAuthRepository();
      final cubit = AuthCubit(repository);

      await cubit.login(email: 'invalid', password: 'secret');

      expect(cubit.state, const AuthFailure('Введите корректный email.'));
      expect(repository.calls, 0);
      await cubit.close();
    });

    test('emits loading then authenticated for valid credentials', () async {
      final repository = _FakeAuthRepository();
      final cubit = AuthCubit(repository);
      final states = <AuthState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.login(email: ' user@jospar.me ', password: 'secret');
      await Future<void>.delayed(Duration.zero);

      expect(states, <AuthState>[
        const AuthLoading(),
        const AuthAuthenticated('jwt-token'),
      ]);
      expect(repository.lastRequest?.email, 'user@jospar.me');
      await subscription.cancel();
      await cubit.close();
    });

    test('logs out and emits unauthenticated', () async {
      final repository = _FakeAuthRepository();
      final cubit = AuthCubit(repository);
      final states = <AuthState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.logout();
      await Future<void>.delayed(Duration.zero);

      expect(states, <AuthState>[
        const AuthLoading(),
        const AuthUnauthenticated(),
      ]);
      expect(repository.logoutCalls, 1);
      await subscription.cancel();
      await cubit.close();
    });
  });
}

class _FakeAuthRepository
    implements AuthRepository, GoogleLoginRepository, AppleLoginRepository {
  String? googleToken = 'google-token';
  String? appleToken = 'apple-token';

  @override
  Future<String?> loginWithApple() async => appleToken;
  @override
  Future<String?> loginWithGoogle() async => googleToken;
  int calls = 0;
  int logoutCalls = 0;
  LoginRequest? lastRequest;
  Future<String>? pendingLogin;
  Future<void>? pendingLogout;

  @override
  Future<String> login(LoginRequest request) async {
    calls += 1;
    lastRequest = request;
    return pendingLogin ?? 'jwt-token';
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await pendingLogout;
  }
}

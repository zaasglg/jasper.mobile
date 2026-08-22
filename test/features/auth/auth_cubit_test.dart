import 'package:flutter_test/flutter_test.dart';
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
  });
}

class _FakeAuthRepository implements AuthRepository {
  int calls = 0;
  LoginRequest? lastRequest;

  @override
  Future<String> login(LoginRequest request) async {
    calls += 1;
    lastRequest = request;
    return 'jwt-token';
  }
}

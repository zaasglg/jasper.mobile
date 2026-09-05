import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/auth/data/models/login_request.dart';
import 'package:jospar/features/auth/domain/repositories/auth_repository.dart';
import 'package:jospar/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:jospar/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('login form validates empty fields locally', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(_NeverCalledRepository()),
          child: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsWidgets);
  });
}

class _NeverCalledRepository implements AuthRepository {
  @override
  Future<String> login(LoginRequest request) {
    throw StateError('Repository should not be called for invalid input');
  }

  @override
  Future<void> logout() {
    throw StateError('Repository should not be called from the login screen');
  }
}

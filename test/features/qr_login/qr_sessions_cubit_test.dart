import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_session_model.dart';
import 'package:jospar/features/qr_login/domain/qr_login_repository.dart';
import 'package:jospar/features/qr_login/presentation/cubit/qr_sessions_cubit.dart';

class _Repository implements QrSessionsRepository {
  final sessions = Completer<List<QrSessionModel>>();
  final revoke = Completer<void>();

  @override
  Future<List<QrSessionModel>> getSessions() => sessions.future;

  @override
  Future<void> revokeSession(String sessionId) => revoke.future;
}

void main() {
  for (final outcome in ['success', 'domain error', 'unexpected error']) {
    test('load handles $outcome after close', () async {
      final repository = _Repository();
      final cubit = QrSessionsCubit(repository);
      final pending = cubit.load();
      final completion = expectLater(pending, completes);
      await cubit.close();

      switch (outcome) {
        case 'success':
          repository.sessions.complete([]);
        case 'domain error':
          repository.sessions.completeError(const QrLoginException('offline'));
        default:
          repository.sessions.completeError(StateError('offline'));
      }

      await completion;
    });

    test('revoke handles $outcome after close', () async {
      final repository = _Repository();
      final cubit = QrSessionsCubit(repository);
      repository.sessions.complete([
        QrSessionModel(
          id: 'session',
          deviceInfo: 'Browser',
          ipAddress: '',
          createdAt: DateTime(2026),
          lastActiveAt: DateTime(2026),
        ),
      ]);
      await cubit.load();
      final pending = cubit.revoke('session');
      final completion = expectLater(pending, completes);
      await cubit.close();

      switch (outcome) {
        case 'success':
          repository.revoke.complete();
        case 'domain error':
          repository.revoke.completeError(const QrLoginException('offline'));
        default:
          repository.revoke.completeError(StateError('offline'));
      }

      await completion;
    });
  }
}

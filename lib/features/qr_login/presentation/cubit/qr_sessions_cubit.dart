import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/qr_login_repository.dart';
import 'qr_sessions_state.dart';

class QrSessionsCubit extends Cubit<QrSessionsState> {
  QrSessionsCubit(this._repository) : super(const QrSessionsLoading());

  final QrSessionsRepository _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(const QrSessionsLoading());
    try {
      final sessions = await _repository.getSessions();
      if (!isClosed) emit(QrSessionsLoaded(sessions));
    } on QrLoginException catch (error) {
      if (!isClosed) emit(QrSessionsFailure(error.message));
    } catch (_) {
      if (!isClosed) {
        emit(const QrSessionsFailure('Не удалось загрузить активные сеансы.'));
      }
    }
  }

  Future<void> revoke(String id) async {
    if (isClosed) return;
    final current = state;
    if (current is! QrSessionsLoaded || current.revokingId != null) return;
    emit(QrSessionsLoaded(current.sessions, revokingId: id));
    try {
      await _repository.revokeSession(id);
      if (isClosed) return;
      emit(
        QrSessionsLoaded(
          current.sessions.where((session) => session.id != id).toList(),
        ),
      );
    } on QrLoginException catch (error) {
      if (!isClosed) emit(QrSessionsFailure(error.message));
    } catch (_) {
      if (!isClosed) {
        emit(const QrSessionsFailure('Не удалось завершить сеанс.'));
      }
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/qr_login_repository.dart';
import 'qr_sessions_state.dart';

class QrSessionsCubit extends Cubit<QrSessionsState> {
  QrSessionsCubit(this._repository) : super(const QrSessionsLoading());

  final QrSessionsRepository _repository;

  Future<void> load() async {
    emit(const QrSessionsLoading());
    try {
      emit(QrSessionsLoaded(await _repository.getSessions()));
    } on QrLoginException catch (error) {
      emit(QrSessionsFailure(error.message));
    } catch (_) {
      emit(const QrSessionsFailure('Не удалось загрузить активные сеансы.'));
    }
  }

  Future<void> revoke(String id) async {
    final current = state;
    if (current is! QrSessionsLoaded || current.revokingId != null) return;
    emit(QrSessionsLoaded(current.sessions, revokingId: id));
    try {
      await _repository.revokeSession(id);
      emit(
        QrSessionsLoaded(
          current.sessions.where((session) => session.id != id).toList(),
        ),
      );
    } on QrLoginException catch (error) {
      emit(QrSessionsFailure(error.message));
    } catch (_) {
      emit(const QrSessionsFailure('Не удалось завершить сеанс.'));
    }
  }
}

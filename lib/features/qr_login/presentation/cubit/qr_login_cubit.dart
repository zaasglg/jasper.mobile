import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/entities/qr_login_details.dart';
import '../../domain/entities/qr_login_payload.dart';
import '../../domain/qr_login_repository.dart';
import 'qr_login_state.dart';

class QrLoginCubit extends Cubit<QrLoginState> {
  QrLoginCubit(this._repository)
    : _generation = authSession.generation,
      super(const QrLoginReady()) {
    authSession.addListener(_onSessionChanged);
  }

  final QrLoginRepository _repository;
  final int _generation;
  QrLoginPayload? _payload;
  Timer? _timer;
  bool _terminal = false;
  bool _leaving = false;

  Future<void> scan(String raw) async {
    if (state is QrLoginScanning || state is QrLoginConfirmation || _terminal) {
      return;
    }
    late final QrLoginPayload payload;
    try {
      payload = _repository.parsePayload(raw);
    } on FormatException {
      emit(const QrLoginReady(message: 'Некорректный QR-код.'));
      return;
    }
    emit(const QrLoginScanning());
    try {
      final details = await _repository.scan(payload);
      if (!_sessionIsCurrent || isClosed || _leaving) {
        if (_sessionIsCurrent) {
          try {
            await _repository.reject(payload);
          } catch (_) {}
        }
        return;
      }
      _payload = payload;
      _startCountdown(details);
    } on QrLoginException catch (error) {
      if (!isClosed && _sessionIsCurrent) {
        emit(QrLoginReady(message: error.message));
      }
    }
  }

  Future<void> approve() async {
    final payload = _payload;
    final current = state;
    if (payload == null ||
        current is! QrLoginConfirmation ||
        current.expired ||
        !_sessionIsCurrent) {
      return;
    }
    _timer?.cancel();
    emit(QrLoginApproving(current.details));
    try {
      await _repository.approve(payload);
      if (!_sessionIsCurrent || isClosed) return;
      _terminal = true;
      _payload = null;
      emit(const QrLoginApproved());
    } on QrLoginException catch (error) {
      if (!isClosed && _sessionIsCurrent) {
        _startCountdown(current.details, message: error.message);
      }
    }
  }

  Future<void> reject() async {
    _leaving = true;
    final payload = _payload;
    _timer?.cancel();
    _payload = null;
    if (payload == null || _terminal) return;
    try {
      await _repository.reject(payload);
    } catch (_) {
      // Best-effort rejection must never block navigation.
    }
  }

  void retryScanning() {
    if (_payload != null || _terminal) return;
    emit(const QrLoginReady());
  }

  bool get _sessionIsCurrent =>
      authSession.generation == _generation && !authSession.requiresLogin;

  void _emitCountdown(QrLoginDetails details, {String? message}) {
    if (isClosed) return;
    final remaining = details.expiresAt.difference(DateTime.now());
    emit(
      QrLoginConfirmation(
        details: details,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        message: message,
      ),
    );
  }

  void _startCountdown(QrLoginDetails details, {String? message}) {
    _timer?.cancel();
    _emitCountdown(details, message: message);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitCountdown(details),
    );
  }

  void _onSessionChanged() {
    if (_sessionIsCurrent || isClosed) return;
    _timer?.cancel();
    _payload = null;
    emit(const QrLoginSessionExpired());
  }

  @override
  Future<void> close() async {
    authSession.removeListener(_onSessionChanged);
    _timer?.cancel();
    unawaited(reject());
    return super.close();
  }
}

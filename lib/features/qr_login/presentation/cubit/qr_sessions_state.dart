import 'package:equatable/equatable.dart';

import '../../data/models/qr_session_model.dart';

sealed class QrSessionsState extends Equatable {
  const QrSessionsState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class QrSessionsLoading extends QrSessionsState {
  const QrSessionsLoading();
}

final class QrSessionsLoaded extends QrSessionsState {
  const QrSessionsLoaded(this.sessions, {this.revokingId});

  final List<QrSessionModel> sessions;
  final String? revokingId;

  @override
  List<Object?> get props => <Object?>[sessions, revokingId];
}

final class QrSessionsFailure extends QrSessionsState {
  const QrSessionsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

import 'package:equatable/equatable.dart';

import '../../data/models/qr_login_details.dart';

sealed class QrLoginState extends Equatable {
  const QrLoginState();
  @override
  List<Object?> get props => const <Object?>[];
}

final class QrLoginReady extends QrLoginState {
  const QrLoginReady({this.message});
  final String? message;
  @override
  List<Object?> get props => <Object?>[message];
}

final class QrLoginScanning extends QrLoginState {
  const QrLoginScanning();
}

final class QrLoginConfirmation extends QrLoginState {
  const QrLoginConfirmation({
    required this.details,
    required this.remaining,
    this.message,
  });
  final QrLoginDetails details;
  final Duration remaining;
  final String? message;
  bool get expired => remaining <= Duration.zero;
  @override
  List<Object?> get props => <Object?>[details, remaining, message];
}

final class QrLoginApproving extends QrLoginState {
  const QrLoginApproving(this.details);
  final QrLoginDetails details;
  @override
  List<Object?> get props => <Object?>[details];
}

final class QrLoginApproved extends QrLoginState {
  const QrLoginApproved();
}

final class QrLoginSessionExpired extends QrLoginState {
  const QrLoginSessionExpired();
}

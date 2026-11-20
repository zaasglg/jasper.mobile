import 'package:equatable/equatable.dart';

class QrLoginPayload extends Equatable {
  const QrLoginPayload({required this.id, required this.scanToken});

  final String id;
  final String scanToken;

  QrLoginPayload copyWith({String? id, String? scanToken}) =>
      QrLoginPayload(id: id ?? this.id, scanToken: scanToken ?? this.scanToken);

  @override
  List<Object?> get props => <Object?>[id, scanToken];
}

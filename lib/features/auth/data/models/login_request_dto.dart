import 'package:equatable/equatable.dart';

import '../../domain/entities/login_request.dart';

class LoginRequestDto extends Equatable {
  const LoginRequestDto({required this.email, required this.password});

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) {
    return LoginRequestDto(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }

  factory LoginRequestDto.fromEntity(LoginRequest entity) =>
      LoginRequestDto(email: entity.email, password: entity.password);

  LoginRequest toEntity() => LoginRequest(email: email, password: password);

  final String email;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'password': password,
  };

  LoginRequestDto copyWith({String? email, String? password}) {
    return LoginRequestDto(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  @override
  List<Object?> get props => <Object?>[email, password];
}

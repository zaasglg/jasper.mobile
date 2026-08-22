import 'package:equatable/equatable.dart';

class LoginRequest extends Equatable {
  const LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }

  final String email;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'password': password,
  };

  LoginRequest copyWith({String? email, String? password}) {
    return LoginRequest(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  @override
  List<Object?> get props => <Object?>[email, password];
}

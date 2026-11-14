import 'package:equatable/equatable.dart';

class AppleSignInCredential extends Equatable {
  const AppleSignInCredential({
    required this.authorizationCode,
    required this.identityToken,
    required this.rawNonce,
    required this.userIdentifier,
    this.email,
    this.givenName,
    this.familyName,
  });

  factory AppleSignInCredential.fromJson(Map<String, dynamic> json) {
    return AppleSignInCredential(
      authorizationCode: json['authorizationCode'] as String,
      identityToken: json['identityToken'] as String,
      rawNonce: json['rawNonce'] as String,
      userIdentifier: json['userIdentifier'] as String,
      email: json['email'] as String?,
      givenName: json['givenName'] as String?,
      familyName: json['familyName'] as String?,
    );
  }

  final String authorizationCode;
  final String identityToken;
  final String rawNonce;
  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'authorizationCode': authorizationCode,
    'identityToken': identityToken,
    'rawNonce': rawNonce,
    'userIdentifier': userIdentifier,
    if (email != null) 'email': email,
    if (givenName != null) 'givenName': givenName,
    if (familyName != null) 'familyName': familyName,
  };

  AppleSignInCredential copyWith({
    String? authorizationCode,
    String? identityToken,
    String? rawNonce,
    String? userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) {
    return AppleSignInCredential(
      authorizationCode: authorizationCode ?? this.authorizationCode,
      identityToken: identityToken ?? this.identityToken,
      rawNonce: rawNonce ?? this.rawNonce,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      email: email ?? this.email,
      givenName: givenName ?? this.givenName,
      familyName: familyName ?? this.familyName,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    authorizationCode,
    identityToken,
    rawNonce,
    userIdentifier,
    email,
    givenName,
    familyName,
  ];
}

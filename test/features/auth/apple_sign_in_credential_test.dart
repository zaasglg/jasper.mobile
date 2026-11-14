import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/auth/data/models/apple_sign_in_credential.dart';

void main() {
  test('Apple credential serializes, deserializes and copies explicitly', () {
    const credential = AppleSignInCredential(
      authorizationCode: 'code',
      identityToken: 'token',
      rawNonce: 'nonce',
      userIdentifier: 'user',
      email: 'user@example.com',
      givenName: 'Jospar',
      familyName: 'User',
    );

    expect(AppleSignInCredential.fromJson(credential.toJson()), credential);
    expect(
      credential.copyWith(email: 'new@example.com').email,
      'new@example.com',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/auth/data/models/login_request_dto.dart';
import 'package:jospar/features/auth/domain/entities/login_request.dart';

void main() {
  group('LoginRequestDto', () {
    const json = <String, dynamic>{
      'email': 'user@jospar.me',
      'password': 'secret',
    };
    const dto = LoginRequestDto(email: 'user@jospar.me', password: 'secret');
    const entity = LoginRequest(email: 'user@jospar.me', password: 'secret');

    test('serializes and parses credentials without changing values', () {
      expect(dto.toJson(), json);
      expect(LoginRequestDto.fromJson(json), dto);
      expect(LoginRequestDto.fromJson(dto.toJson()), dto);
      expect(dto.copyWith(email: 'new@jospar.me').password, 'secret');
      expect(dto.copyWith(password: 'changed').email, dto.email);
    });

    for (final entry in <String, Map<String, dynamic>>{
      'empty object': {},
      'missing email': {'password': 'secret'},
      'missing password': {'email': 'user@jospar.me'},
      'null email': {'email': null, 'password': 'secret'},
      'null password': {'email': 'user@jospar.me', 'password': null},
      'invalid email type': {'email': 42, 'password': 'secret'},
      'invalid password type': {'email': 'user@jospar.me', 'password': []},
    }.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => LoginRequestDto.fromJson(entry.value),
          throwsA(isA<TypeError>()),
        );
      });
    }

    test('fromEntity preserves credentials', () {
      expect(LoginRequestDto.fromEntity(entity), dto);
    });

    test('toEntity preserves credentials', () {
      expect(dto.toEntity(), entity);
    });

    test('entity round trip preserves whitespace and empty strings', () {
      const original = LoginRequest(email: ' user@jospar.me ', password: '');
      expect(LoginRequestDto.fromEntity(original).toEntity(), original);
    });
  });
}

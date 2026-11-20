import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/qr_login/data/models/qr_login_payload_dto.dart';
import 'package:jospar/features/qr_login/data/models/qr_login_details_dto.dart';
import 'package:jospar/features/qr_login/data/models/qr_session_model_dto.dart';
import 'package:jospar/features/qr_login/data/qr_login_repository_impl.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_login_payload.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_login_details.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_session_model.dart';
import 'package:jospar/features/qr_login/domain/qr_login_repository.dart';

const id = '12345678901234567890123456789012';
const token = '1234567890123456789012345678901234567890123';
const payloadJson = {
  'type': 'orbita:qr-login',
  'version': 1,
  'id': id,
  'scanToken': token,
};
void main() {
  test('payload JSON, conversions and copy preserve contract', () {
    const entity = QrLoginPayload(id: id, scanToken: token);
    final dto = QrLoginPayloadDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(dto.toJson(), payloadJson);
    expect(QrLoginPayloadDto.parse(jsonEncode(dto.toJson())), dto);
    expect(entity.copyWith(scanToken: token), entity);
    expect(dto.copyWith(id: id), dto);
  });
  for (final entry in <String, Object?>{
    'type': null,
    'version': '1',
    'id': 123,
    'scanToken': null,
  }.entries) {
    test('rejects missing/null/wrong-type payload ${entry.key}', () {
      final missing = {...payloadJson}..remove(entry.key);
      expect(() => QrLoginPayloadDto.fromJson(missing), throwsFormatException);
      expect(
        () => QrLoginPayloadDto.fromJson({
          ...payloadJson,
          entry.key: entry.value,
        }),
        throwsFormatException,
      );
    });
  }
  test('rejects unsafe characters, lengths and non-object QR strings', () {
    for (final json in <Map<String, dynamic>>[
      {...payloadJson, 'id': 'short'},
      {...payloadJson, 'id': '${id.substring(1)}/'},
      {...payloadJson, 'scanToken': '${token.substring(1)}+'},
      {...payloadJson, 'scanToken': '$token='},
    ]) {
      expect(
        () => QrLoginPayloadDto.parse(jsonEncode(json)),
        throwsFormatException,
      );
    }
    for (final raw in ['[]', 'null', '42', 'invalid', '"string"']) {
      expect(() => QrLoginPayloadDto.parse(raw), throwsFormatException);
    }
  });
  final created = DateTime.utc(2026, 1, 1);
  final expires = created.add(const Duration(minutes: 2));
  test('details map dates, defaults and entity conversions', () {
    final dto = QrLoginDetailsDto.fromJson({
      'status': 'scanned',
      'createdAt': created.toIso8601String(),
      'expiresAt': expires.toIso8601String(),
    });
    final entity = QrLoginDetails(
      status: 'scanned',
      deviceInfo: 'Неизвестное устройство',
      ipAddress: '—',
      createdAt: created,
      expiresAt: expires,
    );
    expect(dto.toEntity(), entity);
    expect(QrLoginDetailsDto.fromEntity(entity), dto);
    expect(QrLoginDetailsDto.fromJson(dto.toJson()), dto);
    expect(dto.copyWith(deviceInfo: 'Device').status, 'scanned');
    expect(entity.copyWith(deviceInfo: 'Device').createdAt, created);
  });
  test(
    'details reject invalid/missing dates, status and wrong string types',
    () {
      final valid = <String, dynamic>{
        'status': 'scanned',
        'createdAt': created.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
      };
      for (final key in ['status', 'createdAt', 'expiresAt']) {
        final missing = {...valid}..remove(key);
        expect(
          () => QrLoginDetailsDto.fromJson(missing),
          throwsFormatException,
        );
        expect(
          () => QrLoginDetailsDto.fromJson({...valid, key: null}),
          throwsFormatException,
        );
      }
      expect(
        () => QrLoginDetailsDto.fromJson({...valid, 'status': 'approved'}),
        throwsFormatException,
      );
      expect(
        () => QrLoginDetailsDto.fromJson({...valid, 'createdAt': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => QrLoginDetailsDto.fromJson({...valid, 'deviceInfo': 42}),
        throwsA(isA<TypeError>()),
      );
    },
  );
  test(
    'session aliases, toString, activity fallback and conversions remain supported',
    () {
      final dto = QrSessionModelDto.fromJson({
        'id': 123,
        'created_at': created.toIso8601String(),
        'userAgent': 'Agent',
        'ip': 'IP',
      });
      final entity = QrSessionModel(
        id: '123',
        deviceInfo: 'Agent',
        ipAddress: 'IP',
        createdAt: created,
        lastActiveAt: created,
      );
      expect(dto.toEntity(), entity);
      expect(QrSessionModelDto.fromEntity(entity), dto);
      expect(QrSessionModelDto.fromJson(dto.toJson()), dto);
      expect(dto.copyWith(ipAddress: 'Other').id, '123');
      expect(entity.copyWith(ipAddress: 'Other').createdAt, created);
      for (final key in ['lastActiveAt', 'lastUsedAt', 'updatedAt']) {
        expect(
          QrSessionModelDto.fromJson({
            ...dto.toJson()..remove('lastActiveAt'),
            key: expires.toIso8601String(),
          }).lastActiveAt,
          expires,
        );
      }
    },
  );
  test('sessions reject missing/null/invalid id and dates', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'id': null},
      {'id': '', 'createdAt': created.toIso8601String()},
      {'id': 'x', 'createdAt': 'bad'},
      {
        'id': 'x',
        'createdAt': created.toIso8601String(),
        'lastActiveAt': 'bad',
      },
    ]) {
      expect(() => QrSessionModelDto.fromJson(json), throwsFormatException);
    }
  });
  test(
    'repository parser is synchronous and never makes a network request',
    () {
      final dio = Dio();
      addTearDown(dio.close);
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests++;
            handler.reject(DioException(requestOptions: request));
          },
        ),
      );
      final repository = QrLoginRepositoryImpl(dio);
      expect(
        repository.parsePayload(jsonEncode(payloadJson)),
        const QrLoginPayload(id: id, scanToken: token),
      );
      expect(
        () => repository.parsePayload('https://malicious.example'),
        throwsFormatException,
      );
      expect(requests, 0);
    },
  );
  for (final wrapped in [false, true]) {
    test(
      'GET session response and DELETE encoded id preserved (wrapped=$wrapped)',
      () async {
        final dio = Dio();
        addTearDown(dio.close);
        final requests = <RequestOptions>[];
        final session = {'id': 'a/b', 'createdAt': created.toIso8601String()};
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: request.method == 'GET'
                      ? (wrapped
                            ? {
                                'sessions': [session],
                              }
                            : [session])
                      : null,
                ),
              );
            },
          ),
        );
        final repository = QrLoginRepositoryImpl(dio);
        final result = await repository.getSessions();
        expect(result.single.id, 'a/b');
        expect(result.single.lastActiveAt, created);
        await repository.revokeSession('a/b');
        expect(requests.map((r) => r.method), ['GET', 'DELETE']);
        expect(requests.map((r) => r.path), [
          'auth/sessions',
          'auth/sessions/a%2Fb',
        ]);
      },
    );
  }
  test('malformed scan response keeps repository exception contract', () async {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) =>
            handler.resolve(Response(requestOptions: request, data: {})),
      ),
    );
    final repository = QrLoginRepositoryImpl(dio);
    await expectLater(
      repository.scan(const QrLoginPayload(id: id, scanToken: token)),
      throwsA(isA<QrLoginException>()),
    );
  });
}

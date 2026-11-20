import 'package:jospar/features/qr_login/data/models/qr_login_payload_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_login_details.dart';
import 'package:jospar/features/qr_login/domain/entities/qr_login_payload.dart';
import 'package:jospar/features/qr_login/data/qr_login_repository_impl.dart';
import 'package:jospar/features/qr_login/domain/qr_login_repository.dart';
import 'package:jospar/features/qr_login/presentation/cubit/qr_login_cubit.dart';
import 'package:jospar/features/qr_login/presentation/cubit/qr_login_state.dart';

const validId = '12345678901234567890123456789012';
const validToken = '1234567890123456789012345678901234567890123';
const validJson =
    '{"type":"orbita:qr-login","version":1,"id":"$validId",'
    '"scanToken":"$validToken"}';

void main() {
  group('QrLoginPayloadDto', () {
    test('accepts only the documented JSON contract', () {
      final payload = QrLoginPayloadDto.parse(validJson);
      expect(payload.id, validId);
      expect(QrLoginPayloadDto.fromJson(payload.toJson()), payload);
      expect(payload.copyWith(id: validId), payload);
    });

    for (final invalid in <String>[
      'https://example.com',
      '{}',
      '{"type":"orbita:qr-login","version":2,"id":"$validId","scanToken":"$validToken"}',
      '{"type":"orbita:qr-login","version":1,"id":"short","scanToken":"$validToken"}',
    ]) {
      test('rejects invalid QR without API access: $invalid', () {
        expect(() => QrLoginPayloadDto.parse(invalid), throwsFormatException);
      });
    }
  });

  test('repository uses scan, approve and reject contracts', () async {
    final paths = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            paths.add(request.path);
            expect(request.data, {'scanToken': validToken});
            final action = request.path.split('/').last;
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                data: action == 'scan'
                    ? {
                        'status': 'scanned',
                        'deviceInfo': 'Safari / macOS',
                        'ipAddress': '127.0.0.1',
                        'createdAt': DateTime.now().toIso8601String(),
                        'expiresAt': DateTime.now()
                            .add(const Duration(seconds: 120))
                            .toIso8601String(),
                      }
                    : {'status': action == 'approve' ? 'approved' : 'rejected'},
              ),
            );
          },
        ),
      );
    addTearDown(dio.close);
    const payload = QrLoginPayload(id: validId, scanToken: validToken);
    final repository = QrLoginRepositoryImpl(dio);

    await repository.scan(payload);
    await repository.approve(payload);
    await repository.reject(payload);

    expect(paths, [
      'auth/qr/$validId/scan',
      'auth/qr/$validId/approve',
      'auth/qr/$validId/reject',
    ]);
  });

  group('QrLoginCubit', () {
    setUp(authSession.markAuthenticated);

    test('scan alone never approves; explicit approve does', () async {
      final repository = _FakeRepository();
      final cubit = QrLoginCubit(repository);
      addTearDown(cubit.close);

      await cubit.scan(validJson);
      expect(cubit.state, isA<QrLoginConfirmation>());
      expect(repository.approveCalls, 0);

      await cubit.approve();
      expect(cubit.state, const QrLoginApproved());
      expect(repository.approveCalls, 1);
    });

    test('invalid QR never reaches scan API', () async {
      final repository = _FakeRepository();
      final cubit = QrLoginCubit(repository);
      addTearDown(cubit.close);

      await cubit.scan('https://malicious.example');

      expect(cubit.state, isA<QrLoginReady>());
      expect(repository.scanCalls, 0);
    });

    test('leaving after scan sends rejection', () async {
      final repository = _FakeRepository();
      final cubit = QrLoginCubit(repository);
      addTearDown(cubit.close);
      await cubit.scan(validJson);

      await cubit.reject();

      expect(repository.rejectCalls, 1);
      expect(repository.approveCalls, 0);
    });

    test('expired QR disables approval', () async {
      final repository = _FakeRepository(expired: true);
      final cubit = QrLoginCubit(repository);
      addTearDown(cubit.close);
      await cubit.scan(validJson);

      expect((cubit.state as QrLoginConfirmation).expired, isTrue);
      await cubit.approve();
      expect(repository.approveCalls, 0);
    });

    test('account/session change clears pending confirmation', () async {
      final repository = _FakeRepository();
      final cubit = QrLoginCubit(repository);
      addTearDown(cubit.close);
      await cubit.scan(validJson);

      authSession.markAuthenticated();

      expect(cubit.state, const QrLoginSessionExpired());
      expect(repository.approveCalls, 0);
    });
  });
}

class _FakeRepository implements QrLoginRepository {
  _FakeRepository({this.expired = false});
  final bool expired;
  int scanCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;

  @override
  QrLoginPayload parsePayload(String raw) =>
      QrLoginPayloadDto.parse(raw).toEntity();

  @override
  Future<QrLoginDetails> scan(QrLoginPayload payload) async {
    scanCalls++;
    final now = DateTime.now();
    return QrLoginDetails(
      status: 'scanned',
      deviceInfo: 'Safari / macOS',
      ipAddress: '127.0.0.1',
      createdAt: now.subtract(const Duration(seconds: 1)),
      expiresAt: now.add(Duration(seconds: expired ? -1 : 120)),
    );
  }

  @override
  Future<void> approve(QrLoginPayload payload) async => approveCalls++;

  @override
  Future<void> reject(QrLoginPayload payload) async => rejectCalls++;
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/network/api_constants.dart';
import 'package:jospar/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';

void main() {
  late Dio dio;
  late ProfileRepositoryImpl repository;
  late List<RequestOptions> requests;
  dynamic response;
  setUp(() {
    dio = Dio();
    repository = ProfileRepositoryImpl(dio);
    requests = [];
    response = {
      'id': '1',
      'name': 'Name',
      'email': 'mail',
      'avatarUrl': '/a.jpg',
    };
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: response),
          );
        },
      ),
    );
  });
  tearDown(() => dio.close());

  for (final wrapped in [false, true]) {
    test('GET maps API response to domain (wrapped: $wrapped)', () async {
      if (wrapped) response = {'data': response};
      final profile = await repository.getCurrentUser();
      expect(
        profile,
        UserProfile(
          id: '1',
          name: 'Name',
          email: 'mail',
          avatarUrl: ApiConstants.origin.resolve('/a.jpg').toString(),
        ),
      );
      expect(requests.single.method, 'GET');
      expect(requests.single.path, 'users/me');
    });
  }
  for (final avatar in ['data:image/png;base64,photo', '']) {
    test('PATCH includes exact avatar string then reloads: $avatar', () async {
      final profile = await repository.updateAvatar(avatar);
      expect(requests.map((r) => r.method), ['PATCH', 'GET']);
      expect(requests.map((r) => r.path), ['users/me/profile', 'users/me']);
      expect(requests.first.data, {'avatarUrl': avatar});
      expect(profile.id, '1');
    });
  }
  test(
    'null avatar is rejected by existing non-nullable API before HTTP',
    () async {
      final dynamic invalid = null;
      await expectLater(
        () => repository.updateAvatar(invalid),
        throwsA(isA<TypeError>()),
      );
      expect(requests, isEmpty);
    },
  );
  for (final invalid in [null, [], 'invalid']) {
    test('rejects non-object API response: $invalid', () async {
      response = invalid;
      await expectLater(
        repository.getCurrentUser(),
        throwsA(isA<ProfileException>()),
      );
    });
  }
}

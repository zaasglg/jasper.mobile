import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';

class _Repository implements ProfileRepository {
  bool fail = false;
  @override
  Future<UserProfile> getCurrentUser() async => const UserProfile(
    id: '1',
    name: 'Имя',
    email: 'test@example.com',
    role: 'ADMIN',
  );
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) async {
    if (fail) throw Exception('offline');
    return (await getCurrentUser()).copyWith(avatarUrl: avatarUrl);
  }
}

void main() {
  test('photo save keeps role and exposes saving and success states', () async {
    final cubit = ProfileCubit(_Repository());
    await cubit.load();
    final states = <ProfileState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.updateAvatar('data:image/png;base64,photo');
    await Future<void>.delayed(Duration.zero);
    expect((states.first as ProfileLoaded).isSavingPhoto, isTrue);
    final loaded = cubit.state as ProfileLoaded;
    expect(loaded.profile.avatarUrl, 'data:image/png;base64,photo');
    expect(loaded.profile.role, 'ADMIN');
    expect(loaded.isSavingPhoto, isFalse);
    await subscription.cancel();
    await cubit.close();
  });

  test('failed photo save preserves profile and allows retry', () async {
    final repository = _Repository()..fail = true;
    final cubit = ProfileCubit(repository);
    await cubit.load();
    final original = (cubit.state as ProfileLoaded).profile;
    await cubit.updateAvatar('photo');
    final failed = cubit.state as ProfileLoaded;
    expect(failed.profile, original);
    expect(failed.photoError, isNotEmpty);
    expect(failed.isSavingPhoto, isFalse);
    repository.fail = false;
    await cubit.updateAvatar('photo');
    expect((cubit.state as ProfileLoaded).photoError, isNull);
    await cubit.close();
  });
}

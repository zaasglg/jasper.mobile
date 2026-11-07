import '../../data/models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentUser();
  Future<UserProfile> updateAvatar(String avatarUrl);
}

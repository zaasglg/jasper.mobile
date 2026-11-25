import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentUser();
  Future<UserProfile> updateAvatar(String avatarUrl);
}

abstract interface class ProfileLocaleRepository {
  Future<UserProfile> updateLocale(String locale);
}

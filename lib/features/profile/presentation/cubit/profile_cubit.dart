import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileInitial());

  final ProfileRepository _repository;

  Future<void> load() async {
    if (state is ProfileLoading ||
        (state is ProfileLoaded && (state as ProfileLoaded).isSavingPhoto)) {
      return;
    }
    emit(const ProfileLoading());
    try {
      final profile = await _repository.getCurrentUser();
      if (!isClosed) emit(ProfileLoaded(profile));
    } on ProfileException catch (error) {
      if (!isClosed) emit(ProfileFailure(error.message));
    } catch (_) {
      if (!isClosed) {
        emit(const ProfileFailure('Не удалось загрузить данные профиля.'));
      }
    }
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final current = state;
    if (current is! ProfileLoaded || current.isSavingPhoto) return;
    emit(ProfileLoaded(current.profile, isSavingPhoto: true));
    try {
      final profile = await _repository.updateAvatar(avatarUrl);
      if (!isClosed) emit(ProfileLoaded(profile));
    } catch (_) {
      if (!isClosed) {
        emit(
          ProfileLoaded(
            current.profile,
            photoError: 'Не удалось сохранить фото. Попробуйте ещё раз.',
          ),
        );
      }
    }
  }
}

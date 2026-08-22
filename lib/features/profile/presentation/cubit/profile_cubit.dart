import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileInitial());

  final ProfileRepository _repository;

  Future<void> load() async {
    if (state is ProfileLoading) return;
    emit(const ProfileLoading());
    try {
      final profile = await _repository.getCurrentUser();
      emit(ProfileLoaded(profile));
    } on ProfileException catch (error) {
      emit(ProfileFailure(error.message));
    } catch (_) {
      emit(const ProfileFailure('Не удалось загрузить данные профиля.'));
    }
  }
}

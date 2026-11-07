import 'package:equatable/equatable.dart';

import '../../data/models/user_profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(
    this.profile, {
    this.isSavingPhoto = false,
    this.photoError,
  });

  final UserProfile profile;
  final bool isSavingPhoto;
  final String? photoError;

  @override
  List<Object?> get props => <Object?>[profile, isSavingPhoto, photoError];
}

final class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

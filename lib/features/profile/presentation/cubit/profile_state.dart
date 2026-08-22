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
  const ProfileLoaded(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => <Object?>[profile];
}

final class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

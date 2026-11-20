import 'package:equatable/equatable.dart';

class SpaceMemberProject extends Equatable {
  const SpaceMemberProject({required this.name});
  final String name;
  SpaceMemberProject copyWith({String? name}) =>
      SpaceMemberProject(name: name ?? this.name);
  @override
  List<Object?> get props => [name];
}

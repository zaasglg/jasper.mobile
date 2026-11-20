import 'package:equatable/equatable.dart';

class CreateWorkspaceRequest extends Equatable {
  const CreateWorkspaceRequest({required this.name, this.color});

  final String name;
  final String? color;

  CreateWorkspaceRequest copyWith({String? name, String? color}) {
    return CreateWorkspaceRequest(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, color];
}

import 'package:equatable/equatable.dart';

class CreateWorkspaceRequest extends Equatable {
  const CreateWorkspaceRequest({required this.name, this.color});

  factory CreateWorkspaceRequest.fromJson(Map<String, dynamic> json) {
    return CreateWorkspaceRequest(
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }

  final String name;
  final String? color;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (color != null) 'color': color,
  };

  CreateWorkspaceRequest copyWith({String? name, String? color}) {
    return CreateWorkspaceRequest(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, color];
}

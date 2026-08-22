import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawAvatarUrl =
        json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'];

    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: rawAvatarUrl is String && rawAvatarUrl.trim().isNotEmpty
          ? _resolveAvatarUrl(rawAvatarUrl.trim())
          : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  static String _resolveAvatarUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse('https://jospar.me').resolve(value).toString();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
  };

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, email, avatarUrl];
}

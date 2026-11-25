import 'package:equatable/equatable.dart';
import '../../../collaboration/data/models/space_member_dto.dart';
import '../../../collaboration/domain/entities/space_member.dart';

class ChannelInfoModel extends Equatable {
  const ChannelInfoModel({
    this.imageUrl,
    this.canManageImage = false,
    this.canManage = false,
    this.members = const [],
  });
  factory ChannelInfoModel.fromJson(
    Map<String, dynamic> json,
  ) => ChannelInfoModel(
    imageUrl: json['imageUrl'] is String ? json['imageUrl'] as String : null,
    canManageImage: json['canManageImage'] == true,
    canManage: json['canManage'] == true,
    members: json['members'] is List
        ? (json['members'] as List)
              .whereType<Map>()
              .map(
                (e) => SpaceMemberDto.fromJson(
                  Map<String, dynamic>.from(e),
                ).toEntity(),
              )
              .toList()
        : const [],
  );
  final String? imageUrl;
  final bool canManageImage, canManage;
  final List<SpaceMember> members;
  static const _unchanged = Object();
  ChannelInfoModel copyWith({
    Object? imageUrl = _unchanged,
    bool? canManageImage,
    bool? canManage,
    List<SpaceMember>? members,
  }) => ChannelInfoModel(
    imageUrl: identical(imageUrl, _unchanged)
        ? this.imageUrl
        : imageUrl as String?,
    canManageImage: canManageImage ?? this.canManageImage,
    canManage: canManage ?? this.canManage,
    members: members ?? this.members,
  );
  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'canManageImage': canManageImage,
    'canManage': canManage,
    'members': members
        .map((e) => SpaceMemberDto.fromEntity(e).toJson())
        .toList(),
  };
  @override
  List<Object?> get props => [imageUrl, canManageImage, canManage, members];
}

import 'package:equatable/equatable.dart';
import '../../data/models/channel_info_model.dart';

abstract interface class ChannelImageRepository {
  Future<ChannelInfoModel> channelInfo(String channelId);
  Future<String?> setChannelImage(String channelId, String? dataUrl);
  Stream<ChannelImageUpdate> get channelImageChanges;
  ChannelImageUpdate? channelImageSnapshot(String channelId);
}

class ChannelImageUpdate extends Equatable {
  const ChannelImageUpdate(this.channelId, this.imageUrl, this.revision);
  factory ChannelImageUpdate.fromJson(Map<String, dynamic> json) =>
      ChannelImageUpdate(
        json['channelId'] as String,
        json['imageUrl'] as String?,
        json['revision'] as int,
      );
  final String channelId;
  final String? imageUrl;
  final int revision;
  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'imageUrl': imageUrl,
    'revision': revision,
  };
  ChannelImageUpdate copyWith({
    String? channelId,
    String? imageUrl,
    bool clearImage = false,
    int? revision,
  }) => ChannelImageUpdate(
    channelId ?? this.channelId,
    clearImage ? null : imageUrl ?? this.imageUrl,
    revision ?? this.revision,
  );
  @override
  List<Object?> get props => [channelId, imageUrl, revision];
}

enum ChannelPhotoError {
  accessDenied,
  format,
  tooLarge,
  decode,
  save,
  load,
  forbidden,
  invalidResponse,
}

class ChannelPhotoException implements Exception {
  const ChannelPhotoException(this.code);
  final ChannelPhotoError code;
}

abstract interface class ChannelPhotoPicker {
  /// Null means the user cancelled. No request should be sent in that case.
  Future<String?> pick();
}

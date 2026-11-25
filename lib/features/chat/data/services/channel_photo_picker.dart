import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../domain/repositories/channel_image_repository.dart';

class GalleryChannelPhotoPicker implements ChannelPhotoPicker {
  GalleryChannelPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  static const maxBytes = 5 * 1024 * 1024;
  @override
  Future<String?> pick() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      if (await file.length() > maxBytes) {
        throw const ChannelPhotoException(ChannelPhotoError.tooLarge);
      }
      final bytes = await file.readAsBytes();
      return await compute(encodeChannelPhoto, bytes);
    } on ChannelPhotoException {
      rethrow;
    } on PlatformException catch (error) {
      if (error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('restricted')) {
        throw const ChannelPhotoException(ChannelPhotoError.accessDenied);
      }
      throw const ChannelPhotoException(ChannelPhotoError.decode);
    } catch (_) {
      throw const ChannelPhotoException(ChannelPhotoError.decode);
    }
  }
}

/// Runs off the UI isolate; EXIF rotation precedes the centered square crop.
String encodeChannelPhoto(Uint8List bytes) {
  if (bytes.length > GalleryChannelPhotoPicker.maxBytes) {
    throw const ChannelPhotoException(ChannelPhotoError.tooLarge);
  }
  final png =
      bytes.length >= 8 &&
      listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final webp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  if (!png && !jpeg && !webp) {
    throw const ChannelPhotoException(ChannelPhotoError.format);
  }
  try {
    img.Image? decoded;
    if (jpeg) {
      // Decode large gallery JPEGs as thumbnails instead of allocating a full
      // camera-resolution bitmap merely to produce a 128-pixel avatar.
      final info = img.JpegDecoder().startDecode(bytes);
      if (info != null) {
        var scale = 1;
        while (scale < 8 &&
            info.width / (scale * 2) >= 128 &&
            info.height / (scale * 2) >= 128) {
          scale *= 2;
        }
        decoded = img.JpegDecoder(scale: scale).decode(bytes, frame: 0);
      }
    } else {
      decoded = img.decodeImage(bytes, frame: 0);
    }
    if (decoded == null) {
      throw const ChannelPhotoException(ChannelPhotoError.decode);
    }
    final square = img.copyResizeCropSquare(
      img.bakeOrientation(decoded),
      size: 128,
      interpolation: img.Interpolation.average,
    );
    final flattened = img.Image(width: 128, height: 128);
    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flattened, square);
    final result =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(flattened, quality: 85))}';
    if (result.length > 100000) {
      throw const ChannelPhotoException(ChannelPhotoError.tooLarge);
    }
    return result;
  } on ChannelPhotoException {
    rethrow;
  } catch (_) {
    throw const ChannelPhotoException(ChannelPhotoError.decode);
  }
}

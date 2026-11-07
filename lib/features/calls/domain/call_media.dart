import 'package:flutter/foundation.dart';
import '../data/call_models.dart';

abstract class CallMedia extends ChangeNotifier {
  bool get ended;
  bool get reconnecting;
  bool get microphone;
  bool get camera;
  bool get screenSharing;
  int get remoteCount;
  Future<void> prepare(bool video);
  Future<void> connect(CallConnection connection);
  Future<void> setMicrophone(bool enabled);
  Future<void> setCamera(bool enabled);
  Future<void> setSpeaker(bool enabled);
  Future<void> setScreenShare(bool enabled);
  Future<void> switchCamera();
  Future<void> disconnect();
}

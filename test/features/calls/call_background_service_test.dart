import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CallBackgroundService.channel, (call) async {
          calls.add(call);
          return call.method == 'consumePendingOpen' ? true : null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    CallBackgroundService.channel.setMethodCallHandler(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CallBackgroundService.channel, null);
  });
  test(
    'start identifies audio and video service types and stop releases service',
    () async {
      await CallBackgroundService.start(camera: false);
      await CallBackgroundService.start(camera: true);
      await CallBackgroundService.stop();
      expect(calls.map((e) => e.method), ['start', 'start', 'stop']);
      expect(calls[0].arguments, {'camera': false, 'screenShare': false});
      expect(calls[1].arguments, {'camera': true, 'screenShare': false});
    },
  );
  test('projection survives camera updates and resets after hangup', () async {
    await CallBackgroundService.start(camera: false, screenShare: true);
    await CallBackgroundService.start(camera: true);
    expect(calls[0].arguments, {'camera': false, 'screenShare': true});
    expect(calls[1].arguments, {'camera': true, 'screenShare': true});
    await CallBackgroundService.stop();
    await CallBackgroundService.start(camera: false);
    expect(calls.last.arguments, {'camera': false, 'screenShare': false});
    await CallBackgroundService.stop();
  });
  test(
    'notification restores the active call through pending launch',
    () async {
      var opened = 0;
      await CallBackgroundService.initialize(
        openCall: () => opened++,
        hangUp: () async {},
      );
      expect(opened, 1);
      expect(calls.single.method, 'consumePendingOpen');
    },
  );
  test('iOS uses native background audio without an Android service', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await CallBackgroundService.start(camera: true);
    await CallBackgroundService.stop();
    expect(calls, isEmpty);
  });
}

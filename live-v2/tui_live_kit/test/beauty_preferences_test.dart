import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_live_uikit/src/common/beauty/beauty_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    support = await Directory.systemTemp.createTemp('livekit-beauty-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => support.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await support.delete(recursive: true);
  });

  test('beauty persists disabled levels and isolates app/account choices',
      () async {
    const first = BeautyPreferences(
        isEnabled: false, smoothLevel: 7, whitenessLevel: 4, ruddyLevel: 2);
    await first.save('app1-user1');
    await const BeautyPreferences(smoothLevel: 3).save('app1-user2');
    final loaded = await BeautyPreferences.load('app1-user1');
    expect(loaded.isEnabled, isFalse);
    expect([loaded.smoothLevel, loaded.whitenessLevel, loaded.ruddyLevel],
        [7, 4, 2]);
    expect((await BeautyPreferences.load('app1-user2')).smoothLevel, 3);
    expect((await BeautyPreferences.load('app2-user1')).smoothLevel, 0);
  });

  test('serialized writes retain latest value and validate persisted levels',
      () async {
    final first = const BeautyPreferences(smoothLevel: 1).save('app-user');
    final latest = const BeautyPreferences(smoothLevel: 5).save('app-user');
    await Future.wait([first, latest]);
    expect((await BeautyPreferences.load('app-user')).smoothLevel, 5);
    await const BeautyPreferences(smoothLevel: -5, whitenessLevel: 80)
        .save('invalid');
    final loaded = await BeautyPreferences.load('invalid');
    expect(loaded.smoothLevel, 0);
    expect(loaded.whitenessLevel, 9);
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_live_uikit/src/common/gift/display/gift_display_view.dart';
import 'package:tencent_live_uikit/src/debug/pusher/pusher_debug_support.dart';
import 'package:tencent_live_uikit/src/pusher/pusher_view.dart';
import 'package:tencent_live_uikit/src/pusher/living/status/pusher_live_status_view.dart';

class Overlay implements GiftDisplayController {
  @override
  ValueChanged<GiftDisplayItem>? onGiftReceived;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'debug projection preserves source and detaches the gift callback on disposal',
      () {
    final support = PusherDebugSupport();
    final overlay = Overlay();
    support.bind(onNeedsRender: () {});
    support.attachGiftDisplay(overlay);
    support.setEnabled(true);
    expect(overlay.onGiftReceived, isNotNull);
    support.setLiving(true);
    final source = PusherPresentationState();
    source.settings.isMuted = true;
    source.settings.captureVolume = 0;
    support.simulationStore!.setAudioStatusOverride(MediaStatus.normal);
    final display = support.transform(source);
    expect(display.settings.isMuted, isFalse);
    expect(display.settings.captureVolume, 100);
    expect(display.deviceStatus.audioStatus, MediaStatus.normal);
    expect(source.settings.isMuted, isTrue);
    expect(source.settings.captureVolume, 0);
    support.setEnabled(false);
    expect(identical(support.transform(source), source), isTrue);
    support.dispose();
    support.dispose();
    expect(overlay.onGiftReceived, isNull);
  });
}

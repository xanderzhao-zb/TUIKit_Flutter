import 'package:flutter/widgets.dart';
import 'package:atomic_x_core/atomicxcore.dart';

import '../../common/gift/display/gift_display_view.dart';
import '../../pusher/pusher_view.dart' show PusherPresentationState;
import '../../pusher/living/status/pusher_live_status_view.dart';
import 'pusher_debug_floating_view.dart';
import 'pusher_debug_gift_store.dart';
import 'pusher_debug_simulation_store.dart';

/// Build with --dart-define=TUILIVEKIT_DEBUG_PANEL=false to omit simulation.
const bool pusherDebugPanelEnabled =
    bool.fromEnvironment('TUILIVEKIT_DEBUG_PANEL', defaultValue: true);

class PusherDebugSupport {
  final PusherDebugSimulationStore? simulationStore =
      pusherDebugPanelEnabled ? PusherDebugSimulationStore() : null;
  final PusherDebugGiftStore? _giftStore =
      pusherDebugPanelEnabled ? PusherDebugGiftStore() : null;
  GiftDisplayController? _giftDisplay;
  VoidCallback? _onNeedsRender;
  bool _isLiving = false;
  bool _disposed = false;
  bool get isEnabled => simulationStore?.isEnabled ?? false;
  bool get _isVisible => isEnabled && _isLiving;

  Widget install() {
    final store = simulationStore;
    if (store == null) return const SizedBox.shrink();
    return Positioned.fill(
        child: Offstage(
            offstage: !_isVisible,
            child: TickerMode(
                enabled: _isVisible,
                child: PusherDebugFloatingView(
                    store: store, giftStore: _giftStore))));
  }

  void bind({required VoidCallback onNeedsRender}) {
    if (_disposed) return;
    _onNeedsRender = onNeedsRender;
    simulationStore?.onStateChanged = () => _onNeedsRender?.call();
    simulationStore?.onGiftReceived = (gift) {
      if (_isVisible) _giftDisplay?.show(gift);
    };
    simulationStore?.onGiftsReset = () => _giftDisplay?.resetPresentation();
    _giftStore?.onStateChanged = () => _onNeedsRender?.call();
  }

  void attachGiftDisplay(GiftDisplayController? controller) {
    if (_disposed || identical(controller, _giftDisplay)) return;
    _giftDisplay?.onGiftReceived = null;
    _giftDisplay = controller;
    if (simulationStore == null) return;
    controller?.onGiftReceived = _giftStore?.recordRealGift;
    _updateVisibility();
  }

  void setLiving(bool living) {
    if (_disposed || _isLiving == living) return;
    _isLiving = living;
    _updateVisibility();
  }

  void setEnabled(bool enabled) {
    if (_disposed) return;
    simulationStore?.setEnabled(enabled);
    _updateVisibility();
  }

  void _updateVisibility() {
    if (!_isVisible) {
      simulationStore?.cancelPendingGiftComments();
      _giftStore?.deactivate();
    }
  }

  PusherPresentationState transform(PusherPresentationState state) {
    final store = simulationStore;
    if (store == null || !store.isEnabled || !store.hasDeviceStatusOverride) {
      return state;
    }
    final display = state.copy();
    final video = store.videoStatusOverride;
    if (video != null) {
      _overrideMedia(display.deviceStatus, video, isVideo: true);
    }
    final audio = store.audioStatusOverride;
    if (audio != null) {
      _overrideMedia(display.deviceStatus, audio, isVideo: false);
      display.settings.isMuted = audio == MediaStatus.off;
      if (audio != MediaStatus.off && display.settings.captureVolume == 0) {
        display.settings.captureVolume = 100;
      }
    }
    final temperature = store.temperatureStatusOverride;
    if (temperature != null) {
      display.deviceStatus.temperatureStatus = temperature;
    }
    final network = store.networkQualityOverride;
    if (network != null) display.deviceStatus.networkQuality = network;
    return display;
  }

  void _overrideMedia(PusherDeviceStatusState state, MediaStatus status,
      {required bool isVideo}) {
    final device =
        status == MediaStatus.off ? DeviceStatus.off : DeviceStatus.on;
    final error = status == MediaStatus.deviceError
        ? DeviceError.unknownError
        : DeviceError.noError;
    if (isVideo) {
      state.cameraStatus = device;
      state.cameraError = error;
      state.hasAVStatistics = true;
      state.frameRate = status == MediaStatus.streamError ? 0 : 30;
      state.videoBitrate = status == MediaStatus.streamError ? 0 : 2000;
      if (status == MediaStatus.normal) state.networkQuality = 1;
    } else {
      state.microphoneStatus = device;
      state.microphoneError = error;
      state.hasAVStatistics = true;
      state.audioSampleRate = status == MediaStatus.streamError ? 0 : 48000;
      state.audioBitrate = status == MediaStatus.streamError ? 0 : 64;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _giftDisplay?.onGiftReceived = null;
    _giftDisplay = null;
    _onNeedsRender = null;
    _giftStore?.onStateChanged = null;
    _giftStore?.deactivate();
    simulationStore?.dispose();
  }
}

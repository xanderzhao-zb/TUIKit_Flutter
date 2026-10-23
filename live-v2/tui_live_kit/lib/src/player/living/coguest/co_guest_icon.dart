import 'dart:async';

import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../common/live_kit_resources.dart';
import '../../../common/platform/audio_foreground_service_channel.dart';
import 'co_guesting_panel.dart';
import 'requesting_panel.dart';
import 'settings_panel.dart';

enum CoGuestStatus { idle, requesting, coGuesting }

class CoGuestIcon extends StatefulWidget {
  const CoGuestIcon({
    super.key,
    this.liveInfo,
    this.onUiStateChanged,
    this.onToast,
  });

  final LiveInfo? liveInfo;
  final ValueChanged<CoGuestStatus>? onUiStateChanged;
  final ValueChanged<String>? onToast;

  @override
  State<CoGuestIcon> createState() => CoGuestIconState();
}

class CoGuestIconState extends State<CoGuestIcon> with WidgetsBindingObserver {
  static const Map<int, String> _applyErrorMessageKeys = <int, String>{
    100004: 'tuilivekit.player.coguest.error.room_not_exist',
    100005: 'tuilivekit.player.coguest.error.not_room_member',
    100200: 'tuilivekit.player.coguest.error.seat_locked',
    100202: 'tuilivekit.player.coguest.error.already_requesting',
    100203: 'tuilivekit.player.coguest.error.already_on_seat',
    100205: 'tuilivekit.player.coguest.error.seat_full',
    100210: 'tuilivekit.player.coguest.error.seat_occupied',
    100211: 'tuilivekit.player.coguest.error.not_supported',
  };

  final ValueNotifier<CoGuestStatus> _uiState =
      ValueNotifier<CoGuestStatus>(CoGuestStatus.idle);
  final ValueNotifier<bool> _openCameraAfterAccept =
      ValueNotifier<bool>(true);
  late final GuestListener _guestListener;
  late final VoidCallback _sdkListener;

  String? _subscribedLiveID;
  LiveInfo? _liveInfo;
  List<SeatUserInfo> _connected = <SeatUserInfo>[];
  OverlayEntry? _overlayEntry;
  _VisiblePanel _visiblePanel = _VisiblePanel.none;
  CoGuestStatus _lastUiState = CoGuestStatus.idle;

  int _requestSeed = 0;
  int? _microphoneRequestID;
  int? _cameraRequestID;
  bool _allowCameraRestore = false;
  bool _microphoneOpened = false;
  bool _audioServiceStarted = false;

  bool get _isAppActive {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  /// 与 Android `CoGuestIcon.startAudioServiceIfNeeded` 一致：仅在麦上且已开麦、
  /// 应用处于前台时启动前台服务。启动失败不改变连麦状态，回前台可再次尝试。
  void startAudioServiceIfNeeded() {
    if (!_microphoneOpened ||
        !mounted ||
        _uiState.value != CoGuestStatus.coGuesting ||
        _liveInfo == null ||
        !_isAppActive) {
      return;
    }
    _audioServiceStarted = true;
    unawaited(AudioForegroundServiceChannel.start());
  }

  Future<void> stopAudioService() async {
    if (!_audioServiceStarted) return;
    _audioServiceStarted = false;
    await AudioForegroundServiceChannel.stop();
  }

  void _updateUiState(CoGuestStatus state) {
    if (_uiState.value == state) return;
    if (_uiState.value == CoGuestStatus.coGuesting && state == CoGuestStatus.idle) {
      invalidateMicrophoneRequests();
      _microphoneOpened = false;
      unawaited(stopAudioService());
      DeviceStore.shared.closeLocalMicrophone();
    }
    _uiState.value = state;
  }

  void invalidateMicrophoneRequests() {
    _microphoneRequestID = null;
  }

  bool invalidateCameraRequests({required bool allowRestore}) {
    final bool wasOpening = _cameraRequestID != null;
    _cameraRequestID = null;
    _allowCameraRestore = allowRestore;
    return wasOpening;
  }

  @override
  void initState() {
    super.initState();
    _sdkListener = _applySDKState;
    _guestListener = GuestListener(
      onGuestApplicationResponded: _handleApplicationResponded,
      onGuestApplicationNoResponse: _handleApplicationNoResponse,
      onKickedOffSeat: _handleKickedOffSeat,
    );
    _uiState.addListener(_handleUiStateChanged);
    WidgetsBinding.instance.addObserver(this);
    final LiveInfo? liveInfo = widget.liveInfo;
    if (liveInfo != null) _bind(liveInfo);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    resumeAudioServiceIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CoGuestIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final LiveInfo? liveInfo = widget.liveInfo;
    if (liveInfo == null) {
      if (oldWidget.liveInfo != null) _unbind();
    } else if (oldWidget.liveInfo?.liveID != liveInfo.liveID) {
      _bind(liveInfo);
    } else {
      _liveInfo = liveInfo;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiState.removeListener(_handleUiStateChanged);
    _overlayEntry?.remove();
    _overlayEntry = null;
    _unbind();
    _uiState.dispose();
    _openCameraAfterAccept.dispose();
    super.dispose();
  }

  /// 回前台重试：与 Android `PlayerViewImpl` 的 ON_RESUME 一致，
  /// 服务此前启动失败或进程被回收后可再次尝试。
  void resumeAudioServiceIfNeeded() {
    if (!_audioServiceStarted) return;
    _audioServiceStarted = false;
    startAudioServiceIfNeeded();
  }

  void _bind(LiveInfo liveInfo) {
    _unbind();
    _liveInfo = liveInfo;
    _subscribedLiveID = liveInfo.liveID;
    final CoGuestStore store = CoGuestStore.create(liveInfo.liveID);
    _connected = List<SeatUserInfo>.from(store.coGuestState.connected.value);
    store.coGuestState.connected.addListener(_sdkListener);
    store.addGuestListener(_guestListener);
    _applySDKState();
  }

  void _unbind() {
    final String? liveID = _subscribedLiveID;
    if (liveID != null && liveID.isNotEmpty) {
      final CoGuestStore store = CoGuestStore.create(liveID);
      store.coGuestState.connected.removeListener(_sdkListener);
      store.removeGuestListener(_guestListener);
    }
    _subscribedLiveID = null;
    _liveInfo = null;
    _connected = <SeatUserInfo>[];
    _visiblePanel = _VisiblePanel.none;
    _removeOverlay();
    _updateUiState(CoGuestStatus.idle);
    _openCameraAfterAccept.value = true;
    _microphoneOpened = false;
    unawaited(stopAudioService());
    DeviceStore.shared.closeLocalMicrophone();
    DeviceStore.shared.closeLocalCamera();
  }

  void _applySDKState() {
    if (_lastUiState == CoGuestStatus.requesting) return;
    final String? liveID = _subscribedLiveID;
    if (liveID == null || liveID.isEmpty) return;
    final CoGuestStore store = CoGuestStore.create(liveID);
    final String selfID =
        LoginStore.shared.loginState.loginUserInfo?.userID ?? '';
    if (selfID.isEmpty) return;
    final bool meConnected = store.coGuestState.connected.value
        .any((SeatUserInfo user) => user.userID == selfID);
    _updateUiState(meConnected
        ? CoGuestStatus.coGuesting
        : CoGuestStatus.idle);

    final List<SeatUserInfo> connectedList =
        store.coGuestState.connected.value;
    final int lastIndex =
        _connected.indexWhere((SeatUserInfo user) => user.userID == selfID);
    final SeatUserInfo? lastSeatUserInfo =
        lastIndex < 0 ? null : _connected[lastIndex];
    _connected = List<SeatUserInfo>.from(connectedList);
    final int index =
        connectedList.indexWhere((SeatUserInfo user) => user.userID == selfID);
    if (lastSeatUserInfo == null || index < 0) return;
    final SeatUserInfo seatUserInfo = connectedList[index];
    if (lastSeatUserInfo.allowOpenMicrophone !=
        seatUserInfo.allowOpenMicrophone) {
      widget.onToast?.call(LiveKitResources.localizedString(
        seatUserInfo.allowOpenMicrophone
            ? 'tuilivekit.player.coguest.microphone_unlocked'
            : 'tuilivekit.player.coguest.microphone_locked',
      ));
    }
  }

  void _handleApplicationResponded(bool accepted, LiveUserInfo hostUser) {
    if (accepted) {
      _removeOverlay();
      _visiblePanel = _VisiblePanel.none;
      final bool openCamera = _openCameraAfterAccept.value;
      _requestMicThenCamera(openCamera);
      _updateUiState(CoGuestStatus.coGuesting);
    } else {
      widget.onToast?.call(LiveKitResources.localizedString(
        'tuilivekit.player.coguest.error.rejected',
      ));
      _openCameraAfterAccept.value = true;
      _updateUiState(CoGuestStatus.idle);
    }
  }

  void _handleApplicationNoResponse(NoResponseReason reason) {
    widget.onToast?.call(LiveKitResources.localizedString(
      reason == NoResponseReason.alreadySeated
          ? 'tuilivekit.player.coguest.error.already_seated'
          : 'tuilivekit.player.coguest.error.timeout',
    ));
    _openCameraAfterAccept.value = true;
    _updateUiState(CoGuestStatus.idle);
  }

  void _handleKickedOffSeat(int seatIndex, LiveUserInfo hostUser) {
    widget.onToast?.call(LiveKitResources.localizedString(
      'tuilivekit.player.coguest.error.kicked_off',
    ));
    invalidateMicrophoneRequests();
    _openCameraAfterAccept.value = true;
    DeviceStore.shared.closeLocalMicrophone();
    DeviceStore.shared.closeLocalCamera();
    _updateUiState(CoGuestStatus.idle);
  }

  Future<void> _requestMicThenCamera(bool openCameraAfterMic) async {
    final int microphoneRequestID = ++_requestSeed;
    _microphoneRequestID = microphoneRequestID;
    final PermissionStatus mic = await Permission.microphone.request();
    if (!mounted) return;
    if (mic.isGranted) {
      await DeviceStore.shared.openLocalMicrophone();
    }
    if (!mounted) return;
    if (_microphoneRequestID == microphoneRequestID) {
      _microphoneRequestID = null;
      if (!_isAppActive ||
          _liveInfo == null ||
          _uiState.value != CoGuestStatus.coGuesting) {
        DeviceStore.shared.closeLocalMicrophone();
      } else if (mic.isGranted) {
        _microphoneOpened = true;
        startAudioServiceIfNeeded();
      }
    } else if (_microphoneRequestID == null) {
      DeviceStore.shared.closeLocalMicrophone();
    }
    if (!openCameraAfterMic) return;
    final int cameraRequestID = ++_requestSeed;
    _cameraRequestID = cameraRequestID;
    final PermissionStatus camera = await Permission.camera.request();
    if (!mounted) return;
    if (!camera.isGranted) {
      if (_cameraRequestID == cameraRequestID) _cameraRequestID = null;
      return;
    }
    await DeviceStore.shared
        .openLocalCamera(DeviceStore.shared.state.isFrontCamera.value);
    if (!mounted) return;
    if (_cameraRequestID == cameraRequestID) {
      _cameraRequestID = null;
      if (!_isAppActive ||
          _liveInfo == null ||
          _uiState.value != CoGuestStatus.coGuesting) {
        DeviceStore.shared.closeLocalCamera();
      }
    } else if (!_isAppActive || (!_allowCameraRestore && _cameraRequestID == null)) {
      DeviceStore.shared.closeLocalCamera();
    }
  }

  void _applyForSeat(bool requestVideo) {
    final LiveInfo? info = _liveInfo;
    if (info == null) return;
    if (_uiState.value != CoGuestStatus.idle) return;
    _openCameraAfterAccept.value = requestVideo;
    CoGuestStore.create(info.liveID)
        .applyForSeat(
          seatIndex: -1,
          timeout: 0,
          extraInfo:
              requestVideo ? '{"mediaType":"video"}' : '{"mediaType":"audio"}',
        )
        .then((CompletionHandler result) {
      if (result.isSuccess) return;
      debugPrint(
        '[PlayerCoGuest] applyForSeat failed: '
        'code=${result.errorCode}, message=${result.errorMessage}',
      );
      if (!mounted) return;
      _openCameraAfterAccept.value = true;
      widget.onToast?.call(LiveKitResources.localizedString(
        _applyErrorMessageKeys[result.errorCode] ??
            'tuilivekit.player.coguest.error.apply_failed',
      ));
      _updateUiState(CoGuestStatus.idle);
    });
    _updateUiState(CoGuestStatus.requesting);
  }

  void _cancelApplication() {
    final LiveInfo? info = _liveInfo;
    if (info == null) return;
    if (_uiState.value != CoGuestStatus.requesting) return;
    CoGuestStore.create(info.liveID)
        .cancelApplication()
        .then((CompletionHandler result) {
      if (result.isSuccess) {
        _openCameraAfterAccept.value = true;
      }
    });
    _updateUiState(CoGuestStatus.idle);
  }

  void _handleUiStateChanged() {
    if (!mounted) return;
    final CoGuestStatus next = _uiState.value;
    if (_lastUiState == next) return;
    _lastUiState = next;
    widget.onUiStateChanged?.call(next);
    if (next != CoGuestStatus.coGuesting &&
        _visiblePanel == _VisiblePanel.connected) {
      _visiblePanel = _VisiblePanel.none;
      _removeOverlay();
    }
    _overlayEntry?.markNeedsBuild();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = _lastUiState == CoGuestStatus.coGuesting;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _liveInfo == null ? null : _presentPanelForCurrentState,
      child: Opacity(
        opacity: _liveInfo == null ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: _CoGuestEntryStyle.background,
            borderRadius: BorderRadius.circular(_CoGuestEntryStyle.size / 2),
            border: Border.all(color: _CoGuestEntryStyle.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: SizedBox(
              width: _CoGuestEntryStyle.size,
              height: _CoGuestEntryStyle.size,
              child: connected
                  ? Image.asset(
                      'assets/livekit_coguest_wave.gif',
                      package: LiveKitResources.packageName,
                      fit: BoxFit.contain,
                    )
                  : Image(
                      image: LiveKitResources.image('livekit_coguest_idle'),
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _presentPanelForCurrentState() {
    _visiblePanel = _lastUiState == CoGuestStatus.coGuesting
        ? _VisiblePanel.connected
        : _VisiblePanel.apply;
    _ensureOverlay();
    _overlayEntry?.markNeedsBuild();
  }

  void _ensureOverlay() {
    if (_overlayEntry != null) return;
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlayIfEmpty() {
    if (_visiblePanel == _VisiblePanel.none) {
      _removeOverlay();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final LiveInfo? liveInfo = _liveInfo;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          if (_visiblePanel == _VisiblePanel.apply && liveInfo != null)
            Positioned.fill(
              child: RequestingPanel(
                liveInfo: liveInfo,
                uiState: _uiState,
                openCameraAfterAccept: _openCameraAfterAccept,
                onDismiss: () {
                  _visiblePanel = _VisiblePanel.none;
                  _removeOverlayIfEmpty();
                },
                onRequestSettings: () {
                  _visiblePanel = _VisiblePanel.previewSettings;
                  _overlayEntry?.markNeedsBuild();
                },
                onApply: _applyForSeat,
                onCancel: _cancelApplication,
              ),
            ),
          if (_visiblePanel == _VisiblePanel.connected && liveInfo != null)
            Positioned.fill(
              child: CoGuestingPanel(
                liveID: liveInfo.liveID,
                openCameraAfterAccept: _openCameraAfterAccept,
                onToast: widget.onToast,
                onCollapse: () {
                  _visiblePanel = _VisiblePanel.none;
                  _removeOverlayIfEmpty();
                },
                onShowSettings: () {
                  _visiblePanel = _VisiblePanel.connectedSettings;
                  _overlayEntry?.markNeedsBuild();
                },
              ),
            ),
          if (_visiblePanel == _VisiblePanel.previewSettings ||
              _visiblePanel == _VisiblePanel.connectedSettings)
            Positioned.fill(
              child: SettingsPanel(
                mode: _visiblePanel == _VisiblePanel.previewSettings
                    ? SettingsPanelMode.preview
                    : SettingsPanelMode.connected,
                onDismiss: () {
                  _visiblePanel = _lastUiState == CoGuestStatus.coGuesting
                      ? _VisiblePanel.connected
                      : _VisiblePanel.apply;
                  _overlayEntry?.markNeedsBuild();
                },
                onRequestCoGuest: () {
                  _applyForSeat(true);
                  _visiblePanel = _VisiblePanel.apply;
                  _removeOverlayIfEmpty();
                },
              ),
            ),
        ],
      ),
    );
  }
}

enum _VisiblePanel {
  none,
  apply,
  previewSettings,
  connected,
  connectedSettings,
}

/// 与底栏其他控件一致的 39 逻辑像素圆底外壳。
abstract final class _CoGuestEntryStyle {
  static const double size = 39;

  /// UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.18)
  static const background = Color(0x2E0A0A0F);

  /// 白色 6% 描边。
  static const border = Color(0x0FFFFFFF);
}

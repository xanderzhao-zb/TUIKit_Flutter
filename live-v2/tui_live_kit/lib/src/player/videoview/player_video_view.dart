import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/widgets.dart';

import '../player_view.dart';
import 'unit_view.dart';

enum PlayerPlaybackState {
  idle,
  loading,
  playing,
  failed,
}

class PlayerVideoViewController {
  final AtomicLiveController coreController =
      AtomicLiveController.create(AtomicLiveViewType.playView);
  final AtomicPlayer player = AtomicPlayer();
  late final AtomicLiveWidget widget = AtomicLiveWidget(controller: coreController);
  late final AtomicLiveViewChangeAdapter _adapter = _PlayerUnitAdapter(this);
  final ValueNotifier<PlayerPlaybackState> state =
      ValueNotifier<PlayerPlaybackState>(PlayerPlaybackState.idle);

  /// 当前 `PlayerStatus`，由 `_PlayerViewControllerImpl` 同步，仅用于席位挂件门控。
  /// `inRoom` / `coGuest` 之外的阶段，`UnitView` 内置规则会隐藏 overlay。
  final ValueNotifier<PlayerStatus> playerStatus =
      ValueNotifier<PlayerStatus>(PlayerStatus.idle);

  String? _playingLiveID;

  /// 当前播放音量，与 iOS `PlayerViewImpl.setVolume` 一样由入口显式设置；
  /// `startPreview` 只用它恢复音量，不再由静音参数推导。
  int volume = 0;
  LiveInfo? _liveInfo;
  LiveInfo? get liveInfo => _liveInfo;

  PlayerVideoViewController() {
    coreController.setViewChangeAdapter(_adapter);
    player.setView(widget);
    player.state.playbackStatus.addListener(_onPlaybackStatus);
  }

  void _onPlaybackStatus() {
    if (_playingLiveID == null) return;
    state.value = switch (player.state.playbackStatus.value) {
      PlayerPlaybackStatus.idle => PlayerPlaybackState.idle,
      PlayerPlaybackStatus.loading => PlayerPlaybackState.loading,
      PlayerPlaybackStatus.playing => PlayerPlaybackState.playing,
    };
  }

  void setLiveInfo(LiveInfo liveInfo) {
    _liveInfo = liveInfo;
  }

  void startPreview({required String liveID}) {
    if (liveID.isEmpty) return;
    if (_playingLiveID == liveID) return;
    _playingLiveID = liveID;
    state.value = PlayerPlaybackState.loading;
    player.setVolume(volume);
    player.startPlay('livekit://liveid=$liveID');
  }

  void setVolume(int value) {
    volume = value;
    if (_playingLiveID == null) return;
    player.setVolume(value);
  }

  void stopPreview() {
    if (_playingLiveID == null) return;
    _playingLiveID = null;
    player.stopPlay();
    state.value = PlayerPlaybackState.idle;
  }

  void dispose() {
    stopPreview();
    player.state.playbackStatus.removeListener(_onPlaybackStatus);
    (_adapter as _PlayerUnitAdapter).dispose();
    state.dispose();
    playerStatus.dispose();
  }
}

class PlayerVideoView extends StatelessWidget {
  const PlayerVideoView({super.key, required this.controller});

  final PlayerVideoViewController controller;

  @override
  Widget build(BuildContext context) => controller.widget;
}

class _PlayerUnitAdapter extends AtomicLiveViewChangeAdapter {
  _PlayerUnitAdapter(this.controller);

  final PlayerVideoViewController controller;
  final Map<int, ValueNotifier<UnitInfo>> _units = {};

  @override
  Widget onCreateUnitView(UnitInfo unitInfo) {
    final notifier = _units.putIfAbsent(
        unitInfo.index, () => ValueNotifier<UnitInfo>(unitInfo));
    notifier.value = unitInfo;
    return ValueListenableBuilder<UnitInfo>(
      valueListenable: notifier,
      builder: (_, unit, __) => ValueListenableBuilder<PlayerStatus>(
        valueListenable: controller.playerStatus,
        builder: (_, status, __) => UnitView(
          unitInfo: unit,
          liveInfo: controller.liveInfo,
          playerStatus: status,
        ),
      ),
    );
  }

  @override
  void onUpdateUnitView(UnitInfo unitInfo, Key? view) {
    _units[unitInfo.index]?.value = unitInfo;
  }

  @override
  void onVideoViewFrameChanged(double left, double top, double right, double bottom) {}

  void dispose() {
    for (final unit in _units.values) {
      unit.dispose();
    }
    _units.clear();
  }
}

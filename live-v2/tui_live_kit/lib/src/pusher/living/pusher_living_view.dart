import '../settings/pusher_settings_action_handling.dart';
import '../video/pusher_video_view.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:atomic_x_core/atomicxcore.dart' show LikeStore, LoginStore;

import '../../common/gift/display/gift_display_view.dart';
import '../../common/gift/gift_barrage_store.dart';
import '../../common/barrage/barrage_input_view.dart';
import '../../common/barrage/barrage_stream_view.dart';
import '../../common/barrage/barrage_ui_store.dart';
import '../../common/like/like_animation_view.dart';
import '../../common/theme/live_toast_view.dart';
import '../../common/live_kit_resources.dart';
import '../../debug/pusher/pusher_debug_simulation_store.dart';
import 'audience/pusher_audience_manage_view.dart';
import '../../common/audience/audience_welcome_view.dart';
import 'audience/pusher_audience_store.dart';
import 'audience/pusher_audience_list_view.dart';
import 'coguest/control_panel/pusher_coguest_settings_view.dart';
import 'coguest/control_panel/pusher_coguest_audience_manage_view.dart';
import 'coguest/pusher_coguest_store.dart';
import 'end_confirm/pusher_end_confirmation_view.dart';
import 'live_bottom_toolbar_view.dart';
import 'live_header_view.dart';
import 'music/pusher_music_view.dart';
import 'pause/pusher_pause_overlay_view.dart';
import 'pusher_living_settings_view.dart';
import 'status/pusher_live_status_view.dart';

class PusherLivingView extends StatefulWidget {
  const PusherLivingView({
    super.key,
    required this.liveID,
    this.debugSimulationStore,
    this.onGiftDisplayAttached,
    required this.coGuestActionHandler,
    required this.hostName,
    required this.hostAvatarURL,
    required this.elapsedSeconds,
    required this.pauseState,
    required this.settings,
    required this.settingsActionHandler,
    required this.deviceStatus,
    required this.coGuestState,
    required this.coGuestChanges,
    required this.coGuestLayout,
    this.onCoGuestStageTap,
    this.coGuestGeometryChanges,
    this.coGuestSmallWindowRegions,
    required this.selectedCoGuestUserID,
    this.onDismissCoGuestActions,
    this.onShowSettings,
    this.onShowBeauty,
    this.onToggleMute,
    this.onPause,
    this.onResume,
    this.onEnd,
    this.onFlipCamera,
  });

  final String liveID;
  final PusherCoGuestActionHandling coGuestActionHandler;
  final String hostName;
  final String hostAvatarURL;
  final ValueListenable<int> elapsedSeconds;
  final ValueListenable<(bool, int)> pauseState;
  final ValueListenable<PusherSettingsState> settings;
  final PusherSettingsActionHandling settingsActionHandler;
  final ValueListenable<PusherDeviceStatusState> deviceStatus;

  final PusherDebugSimulationStore? debugSimulationStore;
  final ValueChanged<GiftDisplayController?>? onGiftDisplayAttached;

  final PusherCoGuestState coGuestState;

  final Listenable coGuestChanges;
  final ValueListenable<(PusherCoGuestLayout, int)> coGuestLayout;

  final bool Function(Offset globalPosition)? onCoGuestStageTap;
  final Listenable? coGuestGeometryChanges;
  final List<Rect> Function()? coGuestSmallWindowRegions;
  final ValueListenable<String?> selectedCoGuestUserID;
  final VoidCallback? onDismissCoGuestActions;

  final VoidCallback? onShowSettings;
  final VoidCallback? onShowBeauty;

  final VoidCallback? onToggleMute;
  final VoidCallback? onPause;

  final VoidCallback? onResume;

  final VoidCallback? onEnd;

  final VoidCallback? onFlipCamera;

  @override
  State<PusherLivingView> createState() => PusherLivingViewState();
}

class PusherLivingViewState extends State<PusherLivingView> with WidgetsBindingObserver {
  bool _isForeground = true;
  late bool _isPaused;
  final _likes = ValueNotifier<int>(0);
  final _audience = ValueNotifier(AudienceState());
  final _comments = ValueNotifier<List<LiveMessage>>(const []);
  final _coGuestUnread = ValueNotifier<bool>(false);

  /// Keep the same precedence as Android PusherLivingView.handleBackPressed.
  /// Only the topmost active UI closes; a paused broadcast remains paused.
  void handleBackPressed() {
    if (_isPaused) return;
    if (widget.selectedCoGuestUserID.value != null) {
      widget.onDismissCoGuestActions?.call();
    } else if (_isCoGuestSettingsVisible) {
      setState(() => _isCoGuestSettingsVisible = false);
    } else if (_isLiveStatusVisible) {
      setState(() => _isLiveStatusVisible = false);
    } else if (_isEndConfirmationVisible) {
      setState(() => _isEndConfirmationVisible = false);
    } else if (_selectedAudience != null) {
      setState(() => _selectedAudience = null);
    } else if (_isAudienceListVisible) {
      setState(() => _isAudienceListVisible = false);
    } else if (_isMusicVisible) {
      setState(() => _isMusicVisible = false);
    } else if (_isSettingsVisible) {
      setState(() => _isSettingsVisible = false);
    } else if (_isCommentComposerVisible) {
      setState(() => _isCommentComposerVisible = false);
    }
  }

  bool get _isCoGuestStageActive =>
      widget.coGuestLayout.value.$2 > 0 || widget.coGuestLayout.value.$1 != PusherCoGuestLayout.floating;

  /// 底部工具栏在安全区之上的高度。
  static const double _toolbarHeight = 68;

  /// 评论区常规高度与评论输入态高度。
  static const double _messageListNormalHeight = 184;
  static const double _messageListComposerHeight = 132;

  static const Duration _continuousTapInterval = Duration(milliseconds: 420);

  final LikeAnimationController _likeAnimationController = LikeAnimationController();
  final LiveToastController _toastController = LiveToastController();
  final GlobalKey _likeLayerKey = GlobalKey();
  final GlobalKey _moreActionKey = GlobalKey();

  late final LikeStore _likeStore;
  int _likeCount = 0;
  bool _isLikeActive = false;
  final _likeSender = LikeSender();
  int get _displayedLikeCount {
    final simulated = _debugStore?.likeCount ?? 0;
    const maximum = 0x7FFFFFFFFFFFFFFF;
    return _likeCount > maximum - simulated ? maximum : _likeCount + simulated;
  }

  void _onReceivedLikes(int count) {
    if (!mounted || !_isForeground || _isPaused) {
      return;
    }
    final Offset? origin = _likeAnimationOrigin();
    if (origin == null) {
      return;
    }
    _likeAnimationController.showReceivedLikes(count: count, auxiliaryOrigin: origin);
  }

  void _activateLikes() {
    _likeStore = LikeStore.create(widget.liveID);
    _isLikeActive = true;
    final store = _likeStore;
    _likeSender.activate((count) => store.sendLike(count).ignore());
    _likeCount = _likeStore.likeState.totalLikeCount.value;
    _likes.value = _displayedLikeCount;
    _likeStore.likeState.totalLikeCount.addListener(_onLikeCountChanged);
  }

  void _onLikeCountChanged() {
    if (!mounted || !_isLikeActive) return;
    final count = _likeStore.likeState.totalLikeCount.value;
    if (count == _likeCount) return;
    _likeCount = count;
    _likes.value = _displayedLikeCount;
  }

  void _registerLike() {
    if (!_isLikeActive || _isPaused || !_isForeground) return;
    _likeSender.sendLike();
  }

  void deactivateLikes({bool discardPending = false}) {
    if (!_isLikeActive) return;
    _isLikeActive = false;
    _likeSender.deactivate(discardPending: discardPending);
    _likeStore.likeState.totalLikeCount.removeListener(_onLikeCountChanged);
  }

  late final BarrageUIStore _barrageStore;
  bool _isCommentActive = false;

  void _activateComments() {
    _barrageStore = BarrageUIStore();
    _barrageStore.onSendError = (message) {
      if (_isCommentActive && mounted) _toastController.show(message);
    };
    _isCommentActive = true;
    _barrageStore.onStateChanged = _onCommentsChanged;
    _barrageStore.activate(
      liveID: widget.liveID,
      hostUserID: LoginStore.shared.loginState.loginUserInfo?.userID ?? '',
    );
  }

  void _onCommentsChanged() {
    if (!_isCommentActive || !mounted) return;
    // The shared comment store owns merging; this is only the Debug projection.
    _officialComments = _barrageStore.comments;
    _syncDebugComments();
  }

  Future<void> _sendComment(String text) => _barrageStore.sendComment(text);

  void deactivateComments() {
    if (!_isCommentActive) return;
    _isCommentActive = false;
    _barrageStore.onStateChanged = null;
    _barrageStore.onSendError = null;
    _barrageStore.deactivate();
    _toastController.dismiss();
    deactivateGiftComments();
  }

  late final GiftBarrageStore _giftBarrageStore;
  bool _isGiftCommentActive = false;

  List<BarrageComment> _officialComments = const [];

  void _syncDebugComments() {
    widget.debugSimulationStore?.mergedComments(_officialComments);
    _refreshDisplayedComments();
  }

  void _refreshDisplayedComments() {
    if (!mounted) return;
    _comments.value = _debugStore?.comments ?? _officialComments;
  }

  void _activateGiftComments() {
    _giftBarrageStore = GiftBarrageStore(liveID: widget.liveID);
    _isGiftCommentActive = true;
    _giftBarrageStore.onGiftBarrageSettled = _appendGiftComment;
    _giftBarrageStore.activate();
    _giftBarrageStore.setEnabled(!_isPaused);
  }

  void deactivateGiftComments() {
    if (!_isGiftCommentActive) return;
    _isGiftCommentActive = false;
    _giftBarrageStore.deactivate();
  }

  void _appendGiftComment(LiveGiftBarrage gift) {
    if (!_isGiftCommentActive || !_isCommentActive) {
      return;
    }
    _barrageStore.appendGiftComment(gift);
  }

  late final PusherAudienceStore _audienceStore;
  AudienceState get _audienceState => _audience.value;

  void _refreshAudiencePresentation() {
    final state = _audienceStore.state.copy();
    final debug = _debugStore;
    if (debug != null) {
      state.users = [...state.users, ...debug.audiences];
      state.count += debug.audienceCount;
    }
    if (!_audience.value.isSameAs(state)) _audience.value = state;
  }

  void refreshAudience() => _audienceStore.refresh();
  void deactivateAudience() {
    _audienceStore.deactivate(resetState: false);
    _audienceEntranceController.reset();
  }

  void _onAudienceStateChanged() {
    if (!mounted) return;
    _refreshAudiencePresentation();
    _dismissDepartedAudience();
  }

  final AudienceWelcomeController _audienceEntranceController = AudienceWelcomeController();

  late final GiftDisplayController _giftDisplayController;
  PusherDebugSimulationStore? get _debugStore {
    final store = widget.debugSimulationStore;
    return store?.isEnabled == true ? store : null;
  }

  void _bindDebug(PusherDebugSimulationStore? store) {
    store?.addListener(_onDebugChanged);
    store?.onCommentsChanged = _refreshDisplayedComments;
    store?.onLikesReceived = (count) {
      if (_debugStore != null) _onReceivedLikes(count);
    };
    store?.onAudienceEntered = (entrance) {
      if (_debugStore != null) _onAudienceEntered(entrance);
    };
    _syncDebugComments();
  }

  void _unbindDebug(PusherDebugSimulationStore? store) {
    store?.removeListener(_onDebugChanged);
    store?.onCommentsChanged = null;
    store?.onLikesReceived = null;
    store?.onAudienceEntered = null;
  }

  void _onDebugChanged() {
    if (!mounted) return;
    _likes.value = _displayedLikeCount;
    _refreshAudiencePresentation();
    _dismissDepartedAudience();
  }

  final _messageVisibleContentHeight = ValueNotifier<double>(0);
  final Stopwatch _stageTapClock = Stopwatch();
  Duration? _lastStageTapTime;
  bool _isAudienceListVisible = false;
  AudienceUser? _selectedAudience;
  final GlobalKey<PusherAudienceManageViewState> _audienceManageKey = GlobalKey();
  bool _isSettingsVisible = false;
  bool _isCommentComposerVisible = false;
  double _commentInputBarHeight = BarrageInputView.inputBarHeight;
  bool _isMusicVisible = false;
  final GlobalKey<PusherMusicViewState> _musicKey = GlobalKey();
  void showCoGuestToast(String message) => _toastController.show(message);

  void deactivateMusic() => _musicKey.currentState?.deactivateMusic();
  bool _isCoGuestSettingsVisible = false;
  bool _isLiveStatusVisible = false;
  bool _isEndConfirmationVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.detached;
    _stageTapClock.start();
    _isPaused = widget.pauseState.value.$1;
    widget.pauseState.addListener(_onPauseChanged);
    widget.coGuestChanges.addListener(_onCoGuestChanged);
    _coGuestUnread.value = widget.coGuestState.hasUnreadApplicant;
    _giftDisplayController = GiftDisplayController(liveID: widget.liveID);
    _giftDisplayController.setSuspended(_isPaused);
    widget.onGiftDisplayAttached?.call(_giftDisplayController);
    _activateLikes();
    _activateComments();
    _activateGiftComments();
    _audienceStore = PusherAudienceStore(liveID: widget.liveID);
    _audienceStore.addListener(_onAudienceStateChanged);
    _audienceStore.onAudienceEntered = _onAudienceEntered;
    _audienceStore.onActionCompleted = (userID, action, succeeded) =>
        _onAudienceActionCompleted(AudienceActionResult(userID: userID, action: action, succeeded: succeeded));
    _audienceStore.activate();
    _audienceStore.refresh();
    _bindDebug(widget.debugSimulationStore);
    _onDebugChanged();
    // 横幅出现时胶囊再上抬 32。
    _audienceEntranceController.addListener(_onAudienceWelcomeVisibilityChanged);
  }

  @override
  void didUpdateWidget(PusherLivingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugSimulationStore != widget.debugSimulationStore) {
      _unbindDebug(oldWidget.debugSimulationStore);
      _bindDebug(widget.debugSimulationStore);
      _onDebugChanged();
    }
    if (oldWidget.pauseState != widget.pauseState) {
      oldWidget.pauseState.removeListener(_onPauseChanged);
      widget.pauseState.addListener(_onPauseChanged);
      _onPauseChanged();
    }
    if (oldWidget.coGuestChanges != widget.coGuestChanges) {
      oldWidget.coGuestChanges.removeListener(_onCoGuestChanged);
      widget.coGuestChanges.addListener(_onCoGuestChanged);
    }
    _onCoGuestChanged();
  }

  void _onCoGuestChanged() {
    _coGuestUnread.value = widget.coGuestState.hasUnreadApplicant;
    // Requests arriving while the open panel is visible are already seen.
    if (widget.coGuestState.hasUnreadApplicant && _isCoGuestSettingsVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isCoGuestSettingsVisible && widget.coGuestState.hasUnreadApplicant) {
          widget.coGuestActionHandler.markApplicantsSeen();
        }
      });
    }
  }

  void _onPauseChanged() {
    final paused = widget.pauseState.value.$1;
    if (_isPaused == paused) return;
    setState(() => _isPaused = paused);
    _giftDisplayController.setSuspended(paused);
    _giftBarrageStore.setEnabled(!paused);
    _musicKey.currentState?.setSuspended(paused || !_isForeground);
    if (paused) {
      _audienceEntranceController.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismissCoGuestActions?.call();
      });
    }
  }

  void _dismissDepartedAudience() {
    final AudienceUser? selectedAudience = _selectedAudience;
    if (selectedAudience != null &&
        !_audienceState.users.any(
          (AudienceUser user) => user.userID == selectedAudience.userID,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && _selectedAudience?.userID == selectedAudience.userID) {
          final panel = _audienceManageKey.currentState;
          if (panel != null) {
            panel.dismiss();
          } else {
            setState(() => _selectedAudience = null);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stageTapClock.stop();
    widget.pauseState.removeListener(_onPauseChanged);
    widget.coGuestChanges.removeListener(_onCoGuestChanged);
    deactivateLikes();
    deactivateComments();
    _giftBarrageStore.dispose();
    _unbindDebug(widget.debugSimulationStore);
    widget.onGiftDisplayAttached?.call(null);
    _giftDisplayController.dispose();
    _audienceStore.onAudienceEntered = null;
    _audienceStore.onActionCompleted = null;
    _audienceStore.removeListener(_onAudienceStateChanged);
    _audienceStore.dispose();
    _audienceEntranceController.removeListener(_onAudienceWelcomeVisibilityChanged);
    _audienceEntranceController.dispose();
    _likeAnimationController.dispose();
    _toastController.dispose();
    _likes.dispose();
    _audience.dispose();
    _comments.dispose();
    _coGuestUnread.dispose();
    _messageVisibleContentHeight.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isForeground) setState(() => _isForeground = true);
      _musicKey.currentState?.setSuspended(_isPaused);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_isForeground) setState(() => _isForeground = false);
      _musicKey.currentState?.setSuspended(true);
      _lastStageTapTime = null;
      _audienceEntranceController.reset();
      _likeAnimationController.removeAllAnimations();
      widget.debugSimulationStore?.cancelPendingGiftComments();
    }
  }

  bool get _canHandleStageLike =>
      _isForeground &&
      !_isPaused &&
      !_isAudienceListVisible &&
      _selectedAudience == null &&
      !_isSettingsVisible &&
      !_isCommentComposerVisible &&
      !_isMusicVisible &&
      !_isCoGuestSettingsVisible &&
      widget.selectedCoGuestUserID.value == null &&
      !_isLiveStatusVisible &&
      !_isEndConfirmationVisible;

  /// 打开抽屉同时把申请标记为已读。
  void _showCoGuestSettings() {
    setState(() => _isCoGuestSettingsVisible = true);
    widget.coGuestActionHandler.markApplicantsSeen();
  }

  void _onAudienceEntered(AudienceWelcome entrance) {
    if (!mounted || !_isForeground || _isPaused) {
      return;
    }
    _audienceEntranceController.enqueue(entrance);
  }

  void _onAudienceActionCompleted(AudienceActionResult result) {
    if (!mounted) return;
    _audienceManageKey.currentState?.completeAction(result.userID, result.action, result.succeeded);
    if (!result.succeeded) return;
    final String key;
    switch (result.action) {
      case AudienceAction.mute:
        key = 'tuilivekit.pusher.audience.muted_toast';
      case AudienceAction.unmute:
        key = 'tuilivekit.pusher.audience.unmuted_toast';
      case AudienceAction.remove:
        key = 'tuilivekit.pusher.audience.removed_toast';
      case AudienceAction.follow:
      case AudienceAction.unfollow:
        return;
    }
    String name = result.userID;
    for (final AudienceUser user in _audienceState.users) {
      if (user.userID == result.userID) {
        name = user.userName.isEmpty ? user.userID : user.userName;
        break;
      }
    }
    _toastController.show(LiveKitResources.localizedFormat(key, name));
  }

  void _onAudienceWelcomeVisibilityChanged() {
    _giftDisplayController.updateAudienceEntranceVisible(
      _audienceEntranceController.active != null,
    );
  }

  Offset? _likeAnimationOrigin() {
    final RenderBox? moreBox = _moreActionKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? layerBox = _likeLayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (moreBox == null || layerBox == null) {
      return null;
    }
    final Offset global = moreBox.localToGlobal(Offset(moreBox.size.width / 2, -10));
    return layerBox.globalToLocal(global);
  }

  void _onStageTap(TapUpDetails details) {
    if (!_canHandleStageLike) {
      _lastStageTapTime = null;
      return;
    }
    if (widget.onCoGuestStageTap?.call(details.globalPosition) == true) {
      _lastStageTapTime = null;
      return;
    }
    final Duration now = _stageTapClock.elapsed;
    final Duration? lastTapTime = _lastStageTapTime;
    _lastStageTapTime = now;
    final bool isContinuousTap = lastTapTime != null && now - lastTapTime <= _continuousTapInterval;
    if (!isContinuousTap) {
      return;
    }

    final RenderBox? layerBox = _likeLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? origin = _likeAnimationOrigin();
    if (layerBox == null || origin == null) {
      return;
    }
    _likeAnimationController.showLocalLike(
      point: layerBox.globalToLocal(details.globalPosition),
      auxiliaryOrigin: origin,
    );
    _registerLike();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).padding;
    final GiftDisplayView giftDisplayView = GiftDisplayView(controller: _giftDisplayController);

    return LayoutBuilder(
        builder: (context, constraints) => Stack(
              children: <Widget>[
                // 舞台连点手势层：与 iOS 一样挂在容器自身，上层按钮会先赢得手势。
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onStageTap,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 170,
                  child: _LivingScrimView(direction: _LivingScrimDirection.top),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // 保持渐变顶部比视频底边高 74，随同一安全区移动。
                  height: 74 + PusherVideoView.bottomInsetOf(context),
                  child: const _LivingScrimView(direction: _LivingScrimDirection.bottom),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  // Android 按 Ardot 77:405 的 46/844 保留顶部留白比例，
                  // 系统保护区独立兜底；iOS 保持模版的 safeArea.top - 1。
                  top: defaultTargetPlatform == TargetPlatform.android
                      ? math.max(MediaQuery.viewPaddingOf(context).top, constraints.maxHeight * 46 / 844)
                      : padding.top - 1,
                  height: 62,
                  child: ListenableBuilder(
                      listenable: Listenable.merge([
                        widget.elapsedSeconds,
                        _likes,
                        _audience,
                        widget.deviceStatus,
                      ]),
                      builder: (context, _) => LiveHeaderView(
                            hostName: widget.hostName,
                            hostAvatarURL: widget.hostAvatarURL,
                            elapsedSeconds: widget.elapsedSeconds.value,
                            likeCount: _likes.value,
                            audience: _audienceState.users,
                            viewerCount: _audienceState.count,
                            networkQuality: widget.deviceStatus.value.networkQuality,
                            onAudience: _showAudienceList,
                            onClose: () => setState(() => _isEndConfirmationVisible = true),
                            onStatus: () => setState(() => _isLiveStatusVisible = true),
                          )),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    widget.coGuestGeometryChanges,
                    widget.coGuestLayout,
                  ]),
                  child: ValueListenableBuilder<List<LiveMessage>>(
                      valueListenable: _comments,
                      builder: (context, messages, _) => BarrageStreamView(
                            messages: messages,
                            onVisibleContentHeightChanged: (double height) {
                              if (!mounted || _messageVisibleContentHeight.value == height) {
                                return;
                              }
                              _giftDisplayController.updateMessageContentHeight(height);
                              _messageVisibleContentHeight.value = height;
                            },
                          )),
                  builder: (context, child) => Positioned(
                    left: 12,
                    // 非输入态对应 iOS bottom = bottomToolbar.top - 14；
                    // 输入态对应 iOS bottom = commentComposer.inputBar.top - 6。
                    bottom: _isCommentComposerVisible
                        ? math.max(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.viewPaddingOf(context).bottom) +
                            BarrageInputView.keyboardGap +
                            _commentInputBarHeight +
                            6
                        : _toolbarHeight + padding.bottom + 14,
                    width: _commentWidth(constraints.biggest, padding),
                    height: _isCommentComposerVisible ? _messageListComposerHeight : _messageListNormalHeight,
                    child: child!,
                  ),
                ),
                ValueListenableBuilder<double>(
                    valueListenable: _messageVisibleContentHeight,
                    builder: (context, messageHeight, child) => AnimatedPositioned(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          left: 0,
                          right: 0,
                          bottom: _toolbarHeight + padding.bottom + 18 + messageHeight,
                          height: AudienceWelcomeView.bannerSize.height,
                          child: AudienceWelcomeView(controller: _audienceEntranceController),
                        )),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _toolbarHeight + padding.bottom,
                  child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _coGuestUnread,
                        widget.coGuestLayout,
                      ]),
                      builder: (context, _) => LiveBottomToolbarView(
                            moreActionKey: _moreActionKey,
                            onMore: _showSettings,
                            onCoGuest: _showCoGuestSettings,
                            hasCoGuestUnread: _coGuestUnread.value,
                            isCoGuestStageActive: _isCoGuestStageActive,
                          )),
                ),
                Positioned.fill(
                  key: _likeLayerKey,
                  child: LikeAnimationView(
                    controller: _likeAnimationController,
                    liveID: _isPaused || !_isForeground ? null : widget.liveID,
                    auxiliaryOriginProvider: _likeAnimationOrigin,
                  ),
                ),
                // 礼物浮层在点赞动画之上、各类抽屉之下。
                Positioned.fill(child: giftDisplayView),
                Positioned.fill(
                  key: const ValueKey('livingSettings'),
                  child: ValueListenableBuilder<PusherSettingsState>(
                      valueListenable: widget.settings,
                      builder: (context, settings, _) => PusherLivingSettingsView(
                            onShowBeauty: widget.onShowBeauty,
                            settings: settings,
                            settingsActionHandler: widget.settingsActionHandler,
                            isPresented: _isSettingsVisible,
                            onDismiss: () => setState(() => _isSettingsVisible = false),
                            onToggleMute: widget.onToggleMute,
                            onPause: widget.onPause,
                            onShowComment: _showCommentComposer,
                            onShowBackgroundMusic: _showBackgroundMusic,
                            onFlipCamera: widget.onFlipCamera,
                          )),
                ),
                Positioned.fill(
                  key: const ValueKey('commentComposer'),
                  child: BarrageInputView(
                    isPresented: _isCommentComposerVisible,
                    onDismiss: () => setState(() => _isCommentComposerVisible = false),
                    onSend: _sendComment,
                    onInputBarHeightChanged: (height) {
                      if (mounted && height != _commentInputBarHeight) {
                        setState(() => _commentInputBarHeight = height);
                      }
                    },
                  ),
                ),
                Positioned.fill(
                  key: const ValueKey('music'),
                  child: PusherMusicView(
                    key: _musicKey,
                    liveID: widget.liveID,
                    isSuspended: _isPaused || !_isForeground,
                    isPresented: _isMusicVisible,
                    onDismiss: () => setState(() => _isMusicVisible = false),
                  ),
                ),
                if (_isPaused)
                  Positioned.fill(
                    child: ValueListenableBuilder<(bool, int)>(
                        valueListenable: widget.pauseState,
                        builder: (context, pause, _) => PusherPauseOverlayView(
                              seconds: pause.$2,
                              onResume: widget.onResume,
                            )),
                  ),
                if (_isAudienceListVisible)
                  Positioned.fill(
                    child: ValueListenableBuilder<AudienceState>(
                        valueListenable: _audience,
                        builder: (context, audience, _) => PusherAudienceListView(
                              audience: _audienceState.users,
                              onDismiss: () => setState(() => _isAudienceListVisible = false),
                              onSelectAudience: (AudienceUser user) {
                                setState(() => _selectedAudience = user);
                                _audienceStore.refreshFollowStatus(user.userID);
                              },
                            )),
                  ),
                if (_selectedAudience case final AudienceUser selectedAudience)
                  Positioned.fill(
                    child: ValueListenableBuilder<AudienceState>(
                        valueListenable: _audience,
                        builder: (context, audience, _) => PusherAudienceManageView(
                              key: _audienceManageKey,
                              user: _audienceState.users.firstWhere(
                                (AudienceUser user) => user.userID == selectedAudience.userID,
                                orElse: () => selectedAudience,
                              ),
                              state: _audienceState,
                              onDismiss: () => setState(() => _selectedAudience = null),
                              onToggleFollow: (String userID) => _audienceStore.toggleFollow(userID),
                              onToggleMessagePermission: (String userID) =>
                                  _audienceStore.toggleMessagePermission(userID),
                              onRemoveFromRoom: (String userID) => _audienceStore.removeFromRoom(userID),
                            )),
                  ),
                if (_isEndConfirmationVisible)
                  Positioned.fill(
                    child: ValueListenableBuilder<AudienceState>(
                        valueListenable: _audience,
                        builder: (context, audience, _) => PusherEndConfirmationView(
                              viewerCount: _audienceState.count,
                              onDismiss: () => setState(() => _isEndConfirmationVisible = false),
                              onConfirmEnd: widget.onEnd,
                            )),
                  ),
                if (_isCoGuestSettingsVisible)
                  Positioned.fill(
                    child: ListenableBuilder(
                        listenable: widget.coGuestChanges,
                        builder: (context, _) => PusherCoGuestSettingsView(
                              state: widget.coGuestState,
                              onDismiss: () => setState(() => _isCoGuestSettingsVisible = false),
                              actionHandler: widget.coGuestActionHandler,
                            )),
                  ),
                if (_isLiveStatusVisible)
                  Positioned.fill(
                    child: ListenableBuilder(
                        listenable: Listenable.merge([
                          widget.elapsedSeconds,
                          _likes,
                          _audience,
                          widget.settings,
                          widget.deviceStatus,
                        ]),
                        builder: (context, _) => PusherLiveStatusView(
                              debugSimulationStore: widget.debugSimulationStore,
                              onSetCaptureVolume: widget.settingsActionHandler.setCaptureVolume,
                              elapsedSeconds: widget.elapsedSeconds.value,
                              viewerCount: _audienceState.count,
                              likeCount: _likes.value,
                              liveID: widget.liveID,
                              settings: widget.settings.value,
                              deviceStatus: widget.deviceStatus.value,
                              onDismiss: () => setState(() => _isLiveStatusVisible = false),
                            )),
                  ),
                // Keep the empty state positioned so it cannot size the stage.
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      widget.selectedCoGuestUserID,
                      widget.coGuestChanges,
                    ]),
                    builder: (context, _) {
                      final userID = widget.selectedCoGuestUserID.value;
                      if (userID == null) return const SizedBox.shrink();
                      return PusherCoGuestAudienceManageView(
                        userID: userID,
                        state: widget.coGuestState,
                        onDismiss: widget.onDismissCoGuestActions,
                        actionHandler: widget.coGuestActionHandler,
                      );
                    },
                  ),
                ),
                Positioned.fill(child: LiveToastView(controller: _toastController)),
              ],
            ));
  }

  double _commentWidth(Size size, EdgeInsets padding) {
    final defaultWidth = math.min(size.width * BarrageStreamView.defaultWidthRatio, size.width - 24);
    final layout = widget.coGuestLayout.value.$1;
    if (layout != PusherCoGuestLayout.floating && layout != PusherCoGuestLayout.fixed) {
      return defaultWidth;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return defaultWidth;
    final bottom = _isCommentComposerVisible
        ? math.max(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.viewPaddingOf(context).bottom) +
            BarrageInputView.keyboardGap +
            _commentInputBarHeight +
            6
        : _toolbarHeight + padding.bottom + 14;
    final height = _isCommentComposerVisible ? _messageListComposerHeight : _messageListNormalHeight;
    final viewportBottom = size.height - bottom;
    var width = defaultWidth;
    for (final region in widget.coGuestSmallWindowRegions?.call() ?? <Rect>[]) {
      final origin = box.globalToLocal(region.topLeft);
      if (origin.dy + region.height > viewportBottom - height && origin.dy < viewportBottom) {
        width = math.min(width, origin.dx - 8 - 12);
      }
    }
    return math.max(17, width);
  }

  void _showSettings() {
    widget.onShowSettings?.call();
    setState(() {
      _isSettingsVisible = true;
    });
  }

  void _showCommentComposer() {
    setState(() {
      _isCommentComposerVisible = true;
    });
  }

  void _showBackgroundMusic() {
    setState(() {
      _isMusicVisible = true;
    });
  }

  void _showAudienceList() {
    _audienceStore.refresh();
    setState(() {
      _isAudienceListVisible = true;
    });
  }
}

enum _LivingScrimDirection { top, bottom }

class _LivingScrimView extends StatelessWidget {
  const _LivingScrimView({required this.direction});

  final _LivingScrimDirection direction;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: direction == _LivingScrimDirection.top
                // UIColor.black.withAlphaComponent(0.5) → clear
                ? const <Color>[Color(0x80000000), Color(0x00000000)]
                // clear → UIColor.black.withAlphaComponent(0.58)
                : const <Color>[Color(0x00000000), Color(0x94000000)],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

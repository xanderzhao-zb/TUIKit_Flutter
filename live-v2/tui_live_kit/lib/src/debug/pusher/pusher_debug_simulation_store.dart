/// 只承载调试模拟数据（观众、评论、点赞）与其时间线合并规则，不触碰真实 SDK。
library;

import 'dart:async';
import '../../common/platform/live_thermal_state_channel.dart';

import 'package:flutter/foundation.dart';

import '../../common/gift/display/gift_display_view.dart';
import '../../common/gift/gift_barrage_store.dart';
import '../../pusher/living/audience/pusher_audience_store.dart';
import '../../common/barrage/barrage_ui_store.dart' show BarrageComment;
import '../../pusher/living/status/pusher_live_status_view.dart';
import '../../common/live_kit_resources.dart';
import 'package:atomic_x_core/atomicxcore.dart';
import 'pusher_debug_fixtures.dart';
import 'pusher_debug_gift_store.dart';

@immutable
class PusherDebugGiftStatistics {
  const PusherDebugGiftStatistics({
    this.giftCount = 0,
    this.senderCount = 0,
    this.score = 0,
  });

  final int giftCount;
  final int senderCount;
  final int score;

  @override
  bool operator ==(Object other) =>
      other is PusherDebugGiftStatistics &&
      other.giftCount == giftCount &&
      other.senderCount == senderCount &&
      other.score == score;

  @override
  int get hashCode => Object.hash(giftCount, senderCount, score);
}

@immutable
class _GiftCommentComboKey {
  const _GiftCommentComboKey({required this.senderID, required this.giftID});

  final String senderID;
  final String giftID;

  @override
  bool operator ==(Object other) =>
      other is _GiftCommentComboKey && other.senderID == senderID && other.giftID == giftID;

  @override
  int get hashCode => Object.hash(senderID, giftID);
}

class _PendingGiftComment {
  _PendingGiftComment({
    required this.gift,
    required this.sender,
    required this.count,
    required this.timerID,
  });

  final PusherDebugGiftResource gift;
  final AudienceUser sender;
  int count;
  int timerID;
  Timer? timer;
}

enum _CommentSource { sdk, simulation }

class _CommentEntry {
  const _CommentEntry({required this.source, required this.comment});

  final _CommentSource source;
  final BarrageComment comment;
}

class PusherDebugSimulationStore extends ChangeNotifier {
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  VoidCallback? onCommentsChanged;
  VoidCallback? onPanelStateChanged;

  void setEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    if (!enabled) cancelPendingGiftComments();
    _notify(commentsChanged: true);
  }

  LiveSummaryData mergingSummaryData(LiveSummaryData data) {
    if (!_isEnabled) return data;
    return LiveSummaryData(
      totalDuration: data.totalDuration,
      totalViewers: _saturatingAdd(data.totalViewers, audienceCount),
      totalGiftsSent: _saturatingAdd(data.totalGiftsSent, giftStatistics.giftCount),
      totalGiftUniqueSenders: _saturatingAdd(data.totalGiftUniqueSenders, giftStatistics.senderCount),
      totalGiftCoins: _saturatingAdd(data.totalGiftCoins, giftStatistics.score),
      totalLikesReceived: _saturatingAdd(data.totalLikesReceived, likeCount),
      totalMessageSent: _saturatingAdd(data.totalMessageSent, simulatedCommentCount),
    );
  }

  @override
  void dispose() {
    cancelPendingGiftComments();
    onStateChanged = null;
    onCommentsChanged = null;
    onPanelStateChanged = null;
    onLikesReceived = null;
    onAudienceEntered = null;
    onGiftReceived = null;
    onGiftsReset = null;
    super.dispose();
  }

  static const int maximumAudienceCount = 999999999;
  static const int _maximumAudienceSamples = 100;

  VoidCallback? onStateChanged;
  void Function(int count)? onLikesReceived;

  void Function(AudienceWelcome entrance)? onAudienceEntered;

  /// 把模拟礼物送进与真实收礼同一条展示链路。
  void Function(GiftDisplayItem gift)? onGiftReceived;

  VoidCallback? onGiftsReset;

  /// null 表示「真实」，即不覆盖 SDK 的真实状态。
  MediaStatus? _videoStatusOverride;
  MediaStatus? _audioStatusOverride;
  LiveThermalState? _temperatureStatusOverride;
  int? _networkQualityOverride;

  MediaStatus? get videoStatusOverride => _videoStatusOverride;
  MediaStatus? get audioStatusOverride => _audioStatusOverride;
  LiveThermalState? get temperatureStatusOverride => _temperatureStatusOverride;
  int? get networkQualityOverride => _networkQualityOverride;

  bool get hasDeviceStatusOverride =>
      _videoStatusOverride != null ||
      _audioStatusOverride != null ||
      _temperatureStatusOverride != null ||
      _networkQualityOverride != null;

  void setVideoStatusOverride(MediaStatus? status) {
    if (_videoStatusOverride == status) {
      return;
    }
    _videoStatusOverride = status;
    _notify();
  }

  void setAudioStatusOverride(MediaStatus? status) {
    if (_audioStatusOverride == status) {
      return;
    }
    _audioStatusOverride = status;
    _notify();
  }

  void setTemperatureStatusOverride(LiveThermalState? status) {
    if (_temperatureStatusOverride == status) {
      return;
    }
    _temperatureStatusOverride = status;
    _notify();
  }

  /// 网络覆盖值语义与 `PusherDeviceStatusState.networkQuality` 一致：0 检测中、1～6 各档。
  void setNetworkQualityOverride(int? quality) {
    if (_networkQualityOverride == quality) {
      return;
    }
    _networkQualityOverride = quality;
    _notify();
  }

  void clearDeviceStatusOverrides() {
    if (!hasDeviceStatusOverride) {
      return;
    }
    _videoStatusOverride = null;
    _audioStatusOverride = null;
    _temperatureStatusOverride = null;
    _networkQualityOverride = null;
    _notify();
  }

  List<AudienceUser> _audiences = <AudienceUser>[];
  int _audienceCount = 0;
  int _likeCount = 0;

  List<AudienceUser> get audiences => _audiences;
  int get audienceCount => _audienceCount;
  int get likeCount => _likeCount;

  /// 只累计模拟礼物，供展示副本叠加到真实统计上。
  PusherDebugGiftStatistics get giftStatistics => _giftStatistics;
  PusherDebugGiftStatistics _giftStatistics = const PusherDebugGiftStatistics();

  /// 送礼人数按去重后的人数统计。
  final Set<String> _giftSenderIDs = <String>{};

  /// 2 秒窗口内的连击合并为一条礼物评论。
  final Map<_GiftCommentComboKey, _PendingGiftComment> _pendingGiftComments =
      <_GiftCommentComboKey, _PendingGiftComment>{};

  static const Duration _giftCommentComboInterval = Duration(seconds: 2);

  int _nextGiftTimerID = 0;

  final List<_CommentEntry> _commentTimeline = <_CommentEntry>[];
  List<BarrageComment> _latestSDKComments = <BarrageComment>[];
  int _nextCommentIndex = 0;

  /// 模拟评论专用自增 ID。
  int _nextCommentID = 0;

  List<BarrageComment> get comments => _commentTimeline.map((entry) => entry.comment).toList(growable: false);

  int get simulatedCommentCount {
    int count = 0;
    for (final _CommentEntry entry in _commentTimeline) {
      if (entry.source == _CommentSource.simulation) {
        count += 1;
      }
    }
    return count;
  }

  void addAudience({int count = 1}) {
    if (count <= 0) {
      return;
    }
    final int next = _saturatingAdd(_audienceCount, count);
    setAudienceCount(next < maximumAudienceCount ? next : maximumAudienceCount);
  }

  void setAudienceCount(int count) {
    final int clamped = count < 0 ? 0 : count;
    final int nextCount = clamped < maximumAudienceCount ? clamped : maximumAudienceCount;
    if (_audienceCount == nextCount) {
      return;
    }
    _audienceCount = nextCount;
    _rebuildAudienceSamples();
    _notify();
  }

  void removeLastAudience() {
    setAudienceCount(_audienceCount - 1);
  }

  void clearAudience() {
    setAudienceCount(0);
  }

  void sendComment(String content, {required int level}) {
    final String text = content.trim();
    if (text.isEmpty) {
      return;
    }
    _appendSimulatedComment(content: text, level: level);
    _notify(commentsChanged: true);
  }

  void sendCommentBatch(int count, {required int level}) {
    if (count <= 0) {
      return;
    }
    for (int index = 0; index < count; index++) {
      final String content = PusherDebugFixtures.comments[_nextCommentIndex % PusherDebugFixtures.comments.length];
      _nextCommentIndex += 1;
      _appendSimulatedComment(content: content, level: level);
    }
    _notify(commentsChanged: true);
  }

  /// 复用入场横幅展示入口，不写入评论历史。
  void sendEntryMessage({required int level}) {
    final AudienceUser audience = _activeCommentAudience;
    _nextCommentIndex += 1;
    onAudienceEntered?.call(
      AudienceWelcome(
        userID: audience.userID,
        userName: audience.userName,
        level: _normalizedLevel(level),
      ),
    );
  }

  void sendSystemMessage(String content) {
    _commentTimeline.add(
      _CommentEntry(
        source: _CommentSource.simulation,
        comment: BarrageComment(
          gift: null,
          isHost: false,
          id: _makeCommentID(),
          userName: LiveKitResources.localizedString('tuilivekit.debug.system'),
          content: content,
          level: 0,
          timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
        ),
      ),
    );
    _notify(commentsChanged: true);
  }

  void clearComments() {
    cancelPendingGiftComments();
    final int previousCount = _commentTimeline.length;
    _commentTimeline.removeWhere((_CommentEntry entry) => entry.source == _CommentSource.simulation);
    if (_commentTimeline.length == previousCount) {
      return;
    }
    _notify(commentsChanged: true);
  }

  void addLikes(int count) {
    final int amount = count < 0 ? 0 : count;
    if (amount <= 0) {
      return;
    }
    _likeCount = _saturatingAdd(_likeCount, amount);
    _notify();
    onLikesReceived?.call(amount < 6 ? amount : 6);
  }

  void clearLikes() {
    if (_likeCount == 0) {
      return;
    }
    _likeCount = 0;
    _notify();
  }

  /// 默认用第一个固定观众作为送礼人。
  void previewGift(PusherDebugGiftResource gift, {required int count}) {
    previewGiftFrom(gift, count: count, sender: PusherDebugFixtures.audience(0));
  }

  /// 只做本地模拟：累计模拟统计、合并礼物评论，并把事件送进与真实收礼
  /// 相同的展示链路，不调用任何礼物 SDK 接口。
  void previewGiftFrom(
    PusherDebugGiftResource gift, {
    required int count,
    required AudienceUser sender,
  }) {
    if (count <= 0) {
      return;
    }
    _accumulateGiftComment(gift, count: count, sender: sender);
    _giftSenderIDs.add(sender.userID);
    _giftStatistics = PusherDebugGiftStatistics(
      score: _saturatingAdd(
        _giftStatistics.score,
        _saturatingMultiply(count, gift.coins),
      ),
      giftCount: _saturatingAdd(
        _giftStatistics.giftCount,
        count,
      ),
      senderCount: _giftSenderIDs.length,
    );
    _notify();
    onGiftReceived?.call(
      GiftDisplayItem(
        giftID: gift.giftID,
        name: gift.name,
        iconURL: gift.iconURL,
        resourceURL: gift.resourceURL,
        coins: gift.coins,
        count: count,
        senderID: sender.userID,
        senderName: sender.userName,
        senderAvatarURL: sender.avatarURL,
      ),
    );
  }

  void clearGifts() {
    cancelPendingGiftComments();
    if (_giftStatistics == const PusherDebugGiftStatistics()) {
      onGiftsReset?.call();
      return;
    }
    _giftStatistics = const PusherDebugGiftStatistics();
    _giftSenderIDs.clear();
    _notify();
    onGiftsReset?.call();
  }

  static int _saturatingAdd(int lhs, int rhs) {
    final int sum = lhs + rhs;
    if (lhs > 0 && rhs > 0 && sum < 0) {
      return _maximumStatisticsValue;
    }
    return sum < 0 ? 0 : sum;
  }

  static int _saturatingMultiply(int lhs, int rhs) {
    if (lhs <= 0 || rhs <= 0) {
      return 0;
    }
    if (lhs > _maximumStatisticsValue ~/ rhs) {
      return _maximumStatisticsValue;
    }
    return lhs * rhs;
  }

  static const int _maximumStatisticsValue = 0x7FFFFFFFFFFFFFFF;

  void cancelPendingGiftComments() {
    for (final _PendingGiftComment pending in _pendingGiftComments.values) {
      pending.timer?.cancel();
    }
    _pendingGiftComments.clear();
  }

  void _accumulateGiftComment(
    PusherDebugGiftResource gift, {
    required int count,
    required AudienceUser sender,
  }) {
    final _GiftCommentComboKey key = _GiftCommentComboKey(
      senderID: sender.userID,
      giftID: gift.giftID,
    );
    final _PendingGiftComment pending = _pendingGiftComments[key] ??
        _PendingGiftComment(
          gift: gift,
          sender: sender,
          count: 0,
          timerID: 0,
        );
    pending.count = _saturatingAdd(pending.count, count);
    pending.timer?.cancel();

    _nextGiftTimerID += 1;
    final int timerID = _nextGiftTimerID;
    pending.timerID = timerID;
    pending.timer = Timer(_giftCommentComboInterval, () {
      _flushGiftComment(key, timerID);
    });
    _pendingGiftComments[key] = pending;
  }

  /// 窗口结束后落一条礼物评论。
  void _flushGiftComment(_GiftCommentComboKey key, int timerID) {
    final _PendingGiftComment? pending = _pendingGiftComments[key];
    if (pending == null || pending.timerID != timerID) {
      return;
    }
    _pendingGiftComments.remove(key);
    final LiveGiftBarrage giftComment = LiveGiftBarrage(
      giftID: pending.gift.giftID,
      giftName: pending.gift.name,
      giftIconURL: pending.gift.iconURL,
      count: pending.count,
      senderID: pending.sender.userID,
      senderName: pending.sender.userName,
      senderLevel: pending.sender.level,
    );
    _commentTimeline.add(
      _CommentEntry(
        source: _CommentSource.simulation,
        comment: BarrageComment(
          isHost: false,
          id: 'gift-${giftComment.id}',
          userName: pending.sender.userName,
          content: '',
          level: 0,
          timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
          gift: giftComment,
        ),
      ),
    );
    _notify(commentsChanged: true);
  }

  void runPeakScenario({PusherDebugGiftResource? gift}) {
    _audienceCount = 100000;
    _rebuildAudienceSamples();
    for (int index = 0; index < 100; index++) {
      final String content = PusherDebugFixtures.comments[_nextCommentIndex % PusherDebugFixtures.comments.length];
      _nextCommentIndex += 1;
      _appendSimulatedComment(content: content, level: 1 + _nextCommentIndex % 50);
    }
    _likeCount = _saturatingAdd(_likeCount, 10000);
    if (gift != null) previewGift(gift, count: 100);
    _notify(commentsChanged: true);
    onLikesReceived?.call(6);
  }

  void reset() {
    cancelPendingGiftComments();
    _giftStatistics = const PusherDebugGiftStatistics();
    _giftSenderIDs.clear();
    _audiences = <AudienceUser>[];
    _audienceCount = 0;
    _likeCount = 0;
    _commentTimeline.removeWhere((_CommentEntry entry) => entry.source == _CommentSource.simulation);
    _nextCommentIndex = 0;
    _videoStatusOverride = null;
    _audioStatusOverride = null;
    _temperatureStatusOverride = null;
    _networkQualityOverride = null;
    _notify(commentsChanged: true);
    onGiftsReset?.call();
  }

  List<BarrageComment> mergedComments(List<BarrageComment> sdkComments) {
    _synchronizeSDKComments(sdkComments);
    return <BarrageComment>[
      for (final _CommentEntry entry in _commentTimeline) entry.comment,
    ];
  }

  void _appendSimulatedComment({required String content, required int level}) {
    final AudienceUser audience = _activeCommentAudience;
    _commentTimeline.add(
      _CommentEntry(
        source: _CommentSource.simulation,
        comment: BarrageComment(
          gift: null,
          isHost: false,
          id: _makeCommentID(),
          userName: audience.userName,
          content: content,
          level: _normalizedLevel(level),
          timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
        ),
      ),
    );
  }

  AudienceUser get _activeCommentAudience {
    if (_audiences.isNotEmpty) {
      return _audiences[_nextCommentIndex % _audiences.length];
    }
    return PusherDebugFixtures.audience(_nextCommentIndex);
  }

  void _rebuildAudienceSamples() {
    final int sampleCount = _audienceCount < _maximumAudienceSamples ? _audienceCount : _maximumAudienceSamples;
    _audiences = <AudienceUser>[
      for (int index = 0; index < sampleCount; index++) PusherDebugFixtures.audience(index),
    ];
  }

  int _normalizedLevel(int level) {
    final int lower = level < 1 ? 1 : level;
    return lower > 50 ? 50 : lower;
  }

  String _makeCommentID() {
    final String id = 'debug_comment_$_nextCommentID';
    _nextCommentID += 1;
    return id;
  }

  /// Dart 侧按 `id` 判定同一条评论。
  void _synchronizeSDKComments(List<BarrageComment> comments) {
    if (_isSameComments(comments, _latestSDKComments)) {
      return;
    }

    if (_startsWith(comments, _latestSDKComments)) {
      for (final BarrageComment comment in comments.skip(_latestSDKComments.length)) {
        _commentTimeline.add(_CommentEntry(source: _CommentSource.sdk, comment: comment));
      }
    } else {
      _commentTimeline.removeWhere((_CommentEntry entry) => entry.source == _CommentSource.sdk);
      for (final BarrageComment comment in comments) {
        _commentTimeline.add(_CommentEntry(source: _CommentSource.sdk, comment: comment));
      }
    }
    _latestSDKComments = List<BarrageComment>.of(comments);
  }

  bool _isSameComments(List<BarrageComment> lhs, List<BarrageComment> rhs) {
    if (lhs.length != rhs.length) {
      return false;
    }
    for (int index = 0; index < lhs.length; index++) {
      if (lhs[index].id != rhs[index].id) {
        return false;
      }
    }
    return true;
  }

  bool _startsWith(List<BarrageComment> comments, List<BarrageComment> prefix) {
    if (comments.length < prefix.length) {
      return false;
    }
    for (int index = 0; index < prefix.length; index++) {
      if (comments[index].id != prefix[index].id) {
        return false;
      }
    }
    return true;
  }

  void _notify({bool commentsChanged = false}) {
    if (commentsChanged) onCommentsChanged?.call();
    onStateChanged?.call();
    onPanelStateChanged?.call();
    notifyListeners();
  }
}

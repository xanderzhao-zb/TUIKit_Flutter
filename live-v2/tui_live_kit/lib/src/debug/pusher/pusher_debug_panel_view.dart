/// 调试面板本体：分组卡片 + 输入框 + 按钮矩阵，全部操作都打到
/// `PusherDebugSimulationStore`，不直连业务 Store。
library;

import '../../common/platform/live_thermal_state_channel.dart';

import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../common/gift/display/gift_display_view.dart';
import '../../pusher/living/audience/pusher_audience_store.dart';
import '../../pusher/living/status/pusher_live_status_view.dart';
import '../../common/live_kit_resources.dart';
import 'pusher_debug_fixtures.dart';
import 'pusher_debug_gift_store.dart';
import 'pusher_debug_simulation_store.dart';

/// 面板按钮样式。
enum _DebugButtonStyle { primary, secondary, destructive, plain }

class PusherDebugPanelView extends StatefulWidget {
  const PusherDebugPanelView({
    super.key,
    required this.store,
    this.giftStore,
    this.onClose,
    this.refreshToken = 0,
  });

  final PusherDebugSimulationStore store;

  final PusherDebugGiftStore? giftStore;

  final VoidCallback? onClose;

  /// 每次呈现面板时自增，驱动输入框回填当前值。
  final int refreshToken;

  @override
  State<PusherDebugPanelView> createState() => _PusherDebugPanelViewState();
}

class _PusherDebugPanelViewState extends State<PusherDebugPanelView> {
  static const Color _panelBackground = Color.fromRGBO(9, 10, 14, 0.78);
  static const Color _primaryFill = Color.fromRGBO(64, 120, 255, 0.68);
  static const Color _selectedSegmentTint = Color.fromRGBO(64, 120, 255, 0.72);
  static const Color _iconTint = Color.fromRGBO(117, 173, 255, 1);
  static const Color _iconBackground = Color.fromRGBO(64, 120, 255, 0.16);
  static const Color _destructiveFill = Color.fromRGBO(255, 56, 71, 0.1);
  static const Color _destructiveText = Color.fromRGBO(255, 107, 117, 1);
  static const List<int> _commentLevels = <int>[1, 10, 25, 40];

  late final TextEditingController _audienceCountController;
  late final TextEditingController _commentController;
  int _selectedLevelIndex = 0;

  /// 分组展开状态。
  final List<bool> _sectionExpanded = <bool>[
    true,
    false,
    false,
    false,
    false,
    false,
  ];

  /// 随机送礼避免连续两次完全相同。
  ({String giftID, String senderID})? _lastRandomGiftCombo;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _audienceCountController = TextEditingController(text: '${widget.store.audienceCount}');
    widget.store.addListener(_onStoreChanged);
    _commentController =
        TextEditingController(text: LiveKitResources.localizedString('tuilivekit.debug.comment_default'));
  }

  @override
  void didUpdateWidget(PusherDebugPanelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
    }
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _audienceCountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// 概要文案在 build 里直接读 Store，此处只回填人数输入框。
  void _onStoreChanged() {
    if (mounted) setState(_refresh);
  }

  void _refresh() {
    _audienceCountController.text = '${widget.store.audienceCount}';
  }

  @override
  Widget build(BuildContext context) {
    final PusherDebugSimulationStore store = widget.store;
    final String summary = LiveKitResources.localizedString('tuilivekit.debug.summary')
        .replaceFirst('%@', _formatted(store.audienceCount))
        .replaceFirst('%@', _formatted(store.simulatedCommentCount))
        .replaceFirst('%@', _formatted(store.likeCount));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.16), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 14),
              child: SizedBox(height: 42, child: _buildHeader(summary)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListView(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: <Widget>[
                    _buildAudienceSection(),
                    const SizedBox(height: 10),
                    _buildMessageSection(),
                    const SizedBox(height: 10),
                    _buildLikeSection(),
                    const SizedBox(height: 10),
                    _buildGiftSection(),
                    const SizedBox(height: 10),
                    _buildDeviceStatusSection(),
                    const SizedBox(height: 10),
                    _buildSceneSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String summary) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SizedBox(
            height: 22,
            child: Center(
              child: Text(
                LiveKitResources.localizedString('tuilivekit.debug.title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 24,
          child: SizedBox(
            height: 16,
            child: Center(
              child: Text(
                summary,
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: 58,
          height: 34,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.common.done'),
            style: _DebugButtonStyle.plain,
            onTap: () => widget.onClose?.call(),
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceSection() {
    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.audience.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.audience.subtitle'),
      icon: Icons.people,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[0],
      onToggle: () => setState(() => _sectionExpanded[0] = !_sectionExpanded[0]),
      children: <Widget>[
        _buildButtonRow(<Widget>[
          _buildButton(title: '+1', onTap: () => _perform((s) => s.addAudience())),
          _buildButton(title: '+10', onTap: () => _perform((s) => s.addAudience(count: 10))),
          _buildButton(title: '+100', onTap: () => _perform((s) => s.addAudience(count: 100))),
          _buildButton(
              title: LiveKitResources.localizedString('tuilivekit.debug.ten_thousand'),
              onTap: () => _perform((s) => s.addAudience(count: 10000))),
        ]),
        _buildTextField(
          controller: _audienceCountController,
          placeholder: LiveKitResources.localizedString('tuilivekit.debug.audience_placeholder'),
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _applyAudienceCount(),
        ),
        _buildButtonRow(<Widget>[
          _buildButton(
              title: LiveKitResources.localizedString('tuilivekit.debug.apply_count'), onTap: _applyAudienceCount),
          _buildButton(
            title: '-1',
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((s) => s.removeLastAudience()),
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.clear'),
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((s) => s.clearAudience()),
          ),
        ]),
      ],
    );
  }

  Widget _buildMessageSection() {
    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.messages.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.messages.subtitle'),
      icon: Icons.chat_bubble,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[1],
      onToggle: () => setState(() => _sectionExpanded[1] = !_sectionExpanded[1]),
      children: <Widget>[
        _buildTextField(
          controller: _commentController,
          placeholder: LiveKitResources.localizedString('tuilivekit.debug.comment_placeholder'),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendCurrentComment(),
        ),
        _buildLevelPickerRow(),
        _buildButtonRow(<Widget>[
          _buildButton(
              title: LiveKitResources.localizedString('tuilivekit.debug.send_comment'), onTap: _sendCurrentComment),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.simulate_entry'),
            onTap: () => _perform((s) => s.sendEntryMessage(level: _selectedCommentLevel)),
          ),
        ]),
        _buildButtonRow(<Widget>[
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.system_short'),
            onTap: () => _perform(
                (s) => s.sendSystemMessage(LiveKitResources.localizedString('tuilivekit.debug.system_short_content'))),
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.system_long'),
            onTap: () => _perform(
              (s) => s.sendSystemMessage(LiveKitResources.localizedString('tuilivekit.debug.system_long_content')),
            ),
          ),
        ]),
        _buildButtonRow(<Widget>[
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.batch_30'),
            onTap: () => _perform((s) => s.sendCommentBatch(30, level: _selectedCommentLevel)),
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.batch_100'),
            onTap: () => _perform((s) => s.sendCommentBatch(100, level: _selectedCommentLevel)),
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.clear_comments'),
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((s) => s.clearComments()),
          ),
        ]),
      ],
    );
  }

  Widget _buildGiftSection() {
    final PusherDebugGiftStore? giftStore = widget.giftStore;
    final PusherDebugGiftResource? selected = giftStore?.selectedGift;
    final bool hasGifts = giftStore != null && giftStore.gifts.isNotEmpty;

    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.gifts.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.gifts.subtitle'),
      icon: Icons.card_giftcard,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[3],
      onToggle: () => setState(() => _sectionExpanded[3] = !_sectionExpanded[3]),
      children: <Widget>[
        _buildGiftCatalogRow(giftStore, selected),
        _buildButtonRow(<Widget>[
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.gift_one'),
            onTap: () {
              if (hasGifts) {
                _previewGift(count: 1);
              }
            },
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.gift_combo'),
            onTap: () {
              if (hasGifts) {
                _previewGift(count: 3);
              }
            },
          ),
          _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.gift_random'),
            onTap: () {
              if (hasGifts) {
                _previewRandomGift();
              }
            },
          ),
        ]),
        _buildGiftInfoText(giftStore, selected),
        SizedBox(
          height: 38,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.clear_gifts'),
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((PusherDebugSimulationStore s) => s.clearGifts()),
          ),
        ),
      ],
    );
  }

  Widget _buildGiftCatalogRow(PusherDebugGiftStore? giftStore, PusherDebugGiftResource? selected) {
    final gifts = giftStore?.gifts ?? [];
    final current = selected == null
        ? LiveKitResources.localizedString('tuilivekit.debug.gift_empty')
        : '${selected.name} · ${selected.giftID}';
    return _buildMenu(
      title: "${LiveKitResources.localizedString('tuilivekit.debug.gift_catalog')} · $current",
      options: gifts.map((gift) => '${gift.name} · ${gift.giftID}').toList(),
      selected: gifts.indexWhere((gift) => gift.giftID == selected?.giftID),
      onSelected: (index) {
        giftStore?.selectGift(gifts[index].giftID);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildGiftInfoText(
    PusherDebugGiftStore? giftStore,
    PusherDebugGiftResource? selected,
  ) {
    final List<String> lines = <String>[];
    if (selected != null) {
      lines.add(
        'ID: ${selected.giftID} · ${selected.coins} coins'
        ' · ${_resourceFormat(selected)}',
      );
      lines.add('icon: ${selected.iconURL.isEmpty ? '-' : selected.iconURL}');
      lines.add(
        'resource: ${selected.resourceURL.isEmpty ? '-' : selected.resourceURL}',
      );
    }
    final GiftDisplayItem? lastReal = giftStore?.lastRealGift;
    if (lastReal != null) {
      lines.add(
        "${LiveKitResources.localizedString('tuilivekit.debug.gift_last_real')}: ${lastReal.giftID} ×${lastReal.count} · ${lastReal.senderID}",
      );
    }
    return Text(
      lines.isEmpty ? LiveKitResources.localizedString('tuilivekit.debug.gift_empty_hint') : lines.join('\n'),
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.52),
        fontSize: 9,
        fontFamily: 'monospace',
      ),
    );
  }

  String _resourceFormat(PusherDebugGiftResource gift) {
    final Uri? uri = Uri.tryParse(gift.resourceURL);
    if (uri == null || uri.pathSegments.isEmpty) {
      return 'none';
    }
    final String last = uri.pathSegments.last;
    final int dot = last.lastIndexOf('.');
    if (dot < 0 || dot == last.length - 1) {
      return 'none';
    }
    return last.substring(dot + 1).toLowerCase();
  }

  void _previewGift({required int count}) {
    final PusherDebugGiftResource? gift = widget.giftStore?.selectedGift;
    if (gift == null) {
      return;
    }
    _perform(
      (PusherDebugSimulationStore s) => s.previewGift(gift, count: count),
    );
  }

  /// 排除与上一次完全相同的礼物与送礼人组合。
  void _previewRandomGift() {
    final PusherDebugGiftStore? giftStore = widget.giftStore;
    if (giftStore == null || giftStore.gifts.isEmpty) {
      return;
    }
    final List<({PusherDebugGiftResource gift, AudienceUser sender})> candidates =
        <({PusherDebugGiftResource gift, AudienceUser sender})>[];
    for (final PusherDebugGiftResource gift in giftStore.gifts) {
      for (int index = 0; index < PusherDebugFixtures.audienceFixtureCount; index++) {
        final AudienceUser sender = PusherDebugFixtures.audience(index);
        final ({String giftID, String senderID})? last = _lastRandomGiftCombo;
        final bool isSameAsLast = last != null && last.giftID == gift.giftID && last.senderID == sender.userID;
        if (!isSameAsLast) {
          candidates.add((gift: gift, sender: sender));
        }
      }
    }
    if (candidates.isEmpty) {
      return;
    }
    final ({PusherDebugGiftResource gift, AudienceUser sender}) picked = candidates[_random.nextInt(candidates.length)];
    _lastRandomGiftCombo = (
      giftID: picked.gift.giftID,
      senderID: picked.sender.userID,
    );
    giftStore.selectGift(picked.gift.giftID);
    _perform(
      (PusherDebugSimulationStore s) => s.previewGiftFrom(picked.gift, count: 1, sender: picked.sender),
    );
  }

  Widget _buildLikeSection() {
    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.likes.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.likes.subtitle'),
      icon: Icons.favorite,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[2],
      onToggle: () => setState(() => _sectionExpanded[2] = !_sectionExpanded[2]),
      children: <Widget>[
        _buildButtonRow(<Widget>[
          _buildButton(title: '+1', onTap: () => _perform((s) => s.addLikes(1))),
          _buildButton(title: '+10', onTap: () => _perform((s) => s.addLikes(10))),
          _buildButton(title: '+50', onTap: () => _perform((s) => s.addLikes(50))),
          _buildButton(
              title: LiveKitResources.localizedString('tuilivekit.debug.ten_thousand'),
              onTap: () => _perform((s) => s.addLikes(10000))),
        ]),
        SizedBox(
          height: 38,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.clear_likes'),
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((s) => s.clearLikes()),
          ),
        ),
      ],
    );
  }

  /// 只覆盖渲染用的展示态，不操作摄像头、麦克风、网络与系统热状态。
  Widget _buildDeviceStatusSection() {
    final PusherDebugSimulationStore store = widget.store;
    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.devices.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.devices.subtitle'),
      icon: Icons.monitor_heart,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[4],
      onToggle: () => setState(() => _sectionExpanded[4] = !_sectionExpanded[4]),
      children: <Widget>[
        _buildOverrideRow<MediaStatus?>(
          title: LiveKitResources.localizedString('tuilivekit.debug.video'),
          options: <(String, MediaStatus?)>[
            (LiveKitResources.localizedString('tuilivekit.debug.real_status'), null),
            (LiveKitResources.localizedString('tuilivekit.debug.normal'), MediaStatus.normal),
            (LiveKitResources.localizedString('tuilivekit.debug.off'), MediaStatus.off),
            (LiveKitResources.localizedString('tuilivekit.debug.device_error'), MediaStatus.deviceError),
            (LiveKitResources.localizedString('tuilivekit.debug.stream_error'), MediaStatus.streamError),
          ],
          value: store.videoStatusOverride,
          onChanged: (MediaStatus? status) =>
              _perform((PusherDebugSimulationStore s) => s.setVideoStatusOverride(status)),
        ),
        _buildOverrideRow<MediaStatus?>(
          title: LiveKitResources.localizedString('tuilivekit.debug.audio'),
          options: <(String, MediaStatus?)>[
            (LiveKitResources.localizedString('tuilivekit.debug.real_status'), null),
            (LiveKitResources.localizedString('tuilivekit.debug.normal'), MediaStatus.normal),
            (LiveKitResources.localizedString('tuilivekit.debug.off'), MediaStatus.off),
            (LiveKitResources.localizedString('tuilivekit.debug.device_error'), MediaStatus.deviceError),
            (LiveKitResources.localizedString('tuilivekit.debug.capture_error'), MediaStatus.streamError),
          ],
          value: store.audioStatusOverride,
          onChanged: (MediaStatus? status) =>
              _perform((PusherDebugSimulationStore s) => s.setAudioStatusOverride(status)),
        ),
        _buildOverrideRow<LiveThermalState?>(
          title: LiveKitResources.localizedString('tuilivekit.debug.temperature'),
          options: <(String, LiveThermalState?)>[
            (LiveKitResources.localizedString('tuilivekit.debug.real_status'), null),
            (LiveKitResources.localizedString('tuilivekit.debug.normal'), LiveThermalState.normal),
            (LiveKitResources.localizedString('tuilivekit.debug.fair_temperature'), LiveThermalState.fair),
            (LiveKitResources.localizedString('tuilivekit.debug.serious_temperature'), LiveThermalState.serious),
          ],
          value: store.temperatureStatusOverride,
          onChanged: (LiveThermalState? status) =>
              _perform((PusherDebugSimulationStore s) => s.setTemperatureStatusOverride(status)),
        ),
        _buildOverrideRow<int?>(
          title: LiveKitResources.localizedString('tuilivekit.debug.network'),
          options: <(String, int?)>[
            (LiveKitResources.localizedString('tuilivekit.debug.real_status'), null),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.checking'), 0),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.excellent'), 1),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.good'), 2),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.poor'), 3),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.bad'), 4),
            (LiveKitResources.localizedString('tuilivekit.pusher.status.network.very_bad'), 5),
            (LiveKitResources.localizedString('tuilivekit.debug.disconnected'), 6),
          ],
          value: store.networkQualityOverride,
          onChanged: (int? quality) => _perform((PusherDebugSimulationStore s) => s.setNetworkQualityOverride(quality)),
        ),
        SizedBox(
          height: 38,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.restore_devices'),
            enabled: store.hasDeviceStatusOverride,
            style: _DebugButtonStyle.secondary,
            onTap: () => _perform((PusherDebugSimulationStore s) => s.clearDeviceStatusOverrides()),
          ),
        ),
      ],
    );
  }

  /// 一行标题加一组横向可滚动的候选项，选中项高亮。
  Widget _buildOverrideRow<T>({
    required String title,
    required List<(String, T)> options,
    required T value,
    required void Function(T value) onChanged,
  }) {
    final selected = options.indexWhere((option) => option.$2 == value);
    return _buildMenu(
      title: '$title · ${options[selected < 0 ? 0 : selected].$1}',
      options: options.map((option) => option.$1).toList(),
      selected: selected,
      onSelected: (index) => onChanged(options[index].$2),
    );
  }

  Widget _buildMenu(
      {required String title,
      required List<String> options,
      required int selected,
      required ValueChanged<int> onSelected}) {
    return SizedBox(
      height: 40,
      child: PopupMenuButton<int>(
        enabled: options.isNotEmpty,
        initialValue: selected < 0 ? null : selected,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (var index = 0; index < options.length; index++)
            CheckedPopupMenuItem<int>(value: index, checked: selected == index, child: Text(options[index])),
        ],
        child: Opacity(
          opacity: options.isEmpty ? .45 : 1,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(9)),
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none)),
          ),
        ),
      ),
    );
  }

  Widget _buildSceneSection() {
    return _DebugSectionView(
      title: LiveKitResources.localizedString('tuilivekit.debug.scenes.title'),
      subtitle: LiveKitResources.localizedString('tuilivekit.debug.scenes.subtitle'),
      icon: Icons.tune,
      iconTint: _iconTint,
      iconBackground: _iconBackground,
      isExpanded: _sectionExpanded[5],
      onToggle: () => setState(() => _sectionExpanded[5] = !_sectionExpanded[5]),
      children: <Widget>[
        SizedBox(
          height: 38,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.peak'),
            onTap: () => _perform((s) => s.runPeakScenario(gift: widget.giftStore?.selectedGift)),
          ),
        ),
        SizedBox(
          height: 38,
          child: _buildButton(
            title: LiveKitResources.localizedString('tuilivekit.debug.reset'),
            style: _DebugButtonStyle.destructive,
            onTap: () => _perform((s) => s.reset()),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelPickerRow() {
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            LiveKitResources.localizedString('tuilivekit.debug.badge_level'),
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildLevelSegmentedControl()),
        ],
      ),
    );
  }

  Widget _buildLevelSegmentedControl() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.06),
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: <Widget>[
            for (int index = 0; index < _commentLevels.length; index++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedLevelIndex = index),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: index == _selectedLevelIndex ? _selectedSegmentTint : null,
                      borderRadius: const BorderRadius.all(Radius.circular(7)),
                    ),
                    child: Center(
                      child: Text(
                        'Lv.${_commentLevels[index]}',
                        style: TextStyle(
                          color:
                              index == _selectedLevelIndex ? Colors.white : const Color.fromRGBO(255, 255, 255, 0.62),
                          fontSize: 11,
                          fontWeight: index == _selectedLevelIndex ? FontWeight.w600 : FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<Widget> buttons) {
    return SizedBox(
      height: 38,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < buttons.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 7),
            Expanded(child: buttons[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    _DebugButtonStyle style = _DebugButtonStyle.primary,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    late final Color background;
    late final Color titleColor;
    switch (style) {
      case _DebugButtonStyle.primary:
        background = _primaryFill;
        titleColor = Colors.white;
      case _DebugButtonStyle.secondary:
        background = const Color.fromRGBO(255, 255, 255, 0.07);
        titleColor = const Color.fromRGBO(255, 255, 255, 0.76);
      case _DebugButtonStyle.destructive:
        background = _destructiveFill;
        titleColor = _destructiveText;
      case _DebugButtonStyle.plain:
        background = const Color.fromRGBO(0, 0, 0, 0);
        titleColor = const Color.fromRGBO(255, 255, 255, 0.9);
    }

    return Opacity(
      opacity: enabled ? 1 : .45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _DebugFittedText(title,
                  minimumScale: .72,
                  style: TextStyle(
                      color: titleColor, fontSize: 11, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required TextInputType keyboardType,
    TextInputAction? textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color.fromRGBO(255, 255, 255, 0.07),
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: (value) {
            onSubmitted(value);
            FocusScope.of(context).unfocus();
          },
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
            hintText: placeholder,
            hintStyle: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.3),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _applyAudienceCount() {
    final String text = _audienceCountController.text.replaceAll(',', '');
    _perform((PusherDebugSimulationStore store) {
      store.setAudienceCount(int.tryParse(text) ?? 0);
    });
  }

  void _sendCurrentComment() {
    _perform((PusherDebugSimulationStore store) {
      store.sendComment(_commentController.text, level: _selectedCommentLevel);
    });
  }

  int get _selectedCommentLevel => _commentLevels[_selectedLevelIndex];

  void _perform(void Function(PusherDebugSimulationStore store) action) {
    action(widget.store);
  }

  String _formatted(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class _DebugSectionView extends StatelessWidget {
  const _DebugSectionView({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconTint,
    required this.iconBackground,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconTint;
  final Color iconBackground;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.055),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(height: 62, child: _buildHeader()),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int index = 0; index < children.length; index++) ...<Widget>[
                      if (index > 0) const SizedBox(height: 8),
                      children[index],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 12,
          top: 13,
          width: 36,
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Center(child: Icon(icon, size: 20, color: iconTint)),
          ),
        ),
        Positioned(
          left: 58,
          right: 38,
          top: 13,
          height: 18,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Positioned(
          left: 58,
          right: 38,
          top: 33,
          height: 15,
          child: _DebugFittedText(subtitle,
              minimumScale: .75,
              style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, .42), fontSize: 10, decoration: TextDecoration.none)),
        ),
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          width: 18,
          child: Center(
            child: Text(
              isExpanded ? '⌃' : '⌄',
              style: const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// UIKit's automatic shrinking has a lower bound; Flutter needs explicit measurement.
class _DebugFittedText extends StatelessWidget {
  const _DebugFittedText(this.text, {required this.minimumScale, required this.style});
  final String text;
  final double minimumScale;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1)
          ..layout();
        final scale = painter.width == 0 ? 1.0 : (constraints.maxWidth / painter.width).clamp(minimumScale, 1.0);
        painter.dispose();
        return Text(text,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: style.fontSize! * scale));
      });
}

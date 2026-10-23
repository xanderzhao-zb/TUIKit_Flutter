/// 结束后的统计页：直播时长、暂停时长与六项本场数据。
library;

import '../living/live_header_view.dart' show LiveHeaderView;

import '../../common/theme/live_theme.dart';
import '../../debug/pusher/pusher_debug_simulation_store.dart';
import 'package:flutter/widgets.dart';

import '../../common/live_kit_resources.dart';
import 'package:atomic_x_core/atomicxcore.dart';

class PusherSummaryContext {
  const PusherSummaryContext(
      {required this.startTime, required this.endTime, required this.pausedSeconds, this.interruptionMessage});
  final DateTime? startTime;
  final DateTime endTime;
  final int pausedSeconds;
  final String? interruptionMessage;
}

class PusherSummaryView extends StatefulWidget {
  const PusherSummaryView(
      {super.key,
      required this.liveID,
      required this.summaryContext,
      this.summaryStore,
      this.finalSummary,
      this.debugSimulationStore,
      this.onExit});
  final String liveID;
  final PusherSummaryContext summaryContext;
  final LiveSummaryStore? summaryStore;
  final PusherSummary? finalSummary;
  final PusherDebugSimulationStore? debugSimulationStore;
  final VoidCallback? onExit;
  @override
  State<PusherSummaryView> createState() => _PusherSummaryViewState();
}

class _PusherSummaryViewState extends State<PusherSummaryView> {
  LiveSummaryStore? _summaryStore;
  bool get _hasData => widget.finalSummary != null || _summaryStore != null;
  LiveSummaryData _officialSummary = LiveSummaryData();
  LiveSummaryData get _summary => widget.debugSimulationStore?.mergingSummaryData(_officialSummary) ?? _officialSummary;
  @override
  void initState() {
    super.initState();
    _summaryStore = widget.summaryStore;
    _readSummary();
    _summaryStore?.liveSummaryState.summaryData.addListener(_onSummaryChanged);
    widget.debugSimulationStore?.addListener(_onSummaryChanged);
  }

  @override
  void didUpdateWidget(PusherSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _readSummary();
    if (oldWidget.debugSimulationStore != widget.debugSimulationStore) {
      oldWidget.debugSimulationStore?.removeListener(_onSummaryChanged);
      widget.debugSimulationStore?.addListener(_onSummaryChanged);
    }
  }

  void _onSummaryChanged() {
    if (!mounted) return;
    setState(_readSummary);
  }

  void _readSummary() {
    final summary = widget.finalSummary;
    _officialSummary = summary == null
        ? (_summaryStore?.liveSummaryState.summaryData.value ?? LiveSummaryData())
        : LiveSummaryData(
            totalDuration: summary.liveDuration * 1000,
            totalViewers: summary.totalViewers,
            totalGiftsSent: summary.totalGiftsSent,
            totalGiftCoins: summary.totalGiftCoins,
            totalGiftUniqueSenders: summary.totalUniqueGiftSenders,
            totalLikesReceived: summary.totalLikesReceived,
            totalMessageSent: summary.totalMessageCount);
  }

  @override
  void dispose() {
    _summaryStore?.liveSummaryState.summaryData.removeListener(_onSummaryChanged);
    widget.debugSimulationStore?.removeListener(_onSummaryChanged);
    super.dispose();
  }

  static String formatDuration(int seconds) => LiveHeaderView.formatDuration(seconds < 0 ? 0 : seconds);

  static String _formatClock(DateTime? time) {
    if (time == null) {
      return '--:--';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static const List<(String, String, Color)> _statCards = <(String, String, Color)>[
    ('gifts_received', 'items', _PusherSummaryStyle.giftsAccent),
    ('gift_value', 'coins', _PusherSummaryStyle.giftValueAccent),
    ('viewers', 'people', _PusherSummaryStyle.viewersAccent),
    ('comments', 'messages', _PusherSummaryStyle.commentsAccent),
    ('gift_senders', 'people', _PusherSummaryStyle.sendersAccent),
    ('likes', 'times', _PusherSummaryStyle.likesAccent),
  ];

  @override
  Widget build(BuildContext context) {
    final int pausedSeconds = widget.summaryContext.pausedSeconds;
    final String timeRange =
        '${_formatClock(widget.summaryContext.startTime)} ~ ${_formatClock(widget.summaryContext.endTime)}';
    final List<int> values = [
      _summary.totalGiftsSent,
      _summary.totalGiftCoins,
      _summary.totalViewers,
      _summary.totalMessageSent,
      _summary.totalGiftUniqueSenders,
      _summary.totalLikesReceived,
    ];

    return Stack(
      children: <Widget>[
        Positioned.fill(child: Image(image: LiveKitResources.image('livekit_summary_bg'), fit: BoxFit.cover)),
        // 卡片之间相对串联，
        // 短屏可完整查看最后一行数据，390pt 基准的顺序与间距不变。
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // headerView：top 34、height 58。
                const SizedBox(height: 34),
                SizedBox(
                  height: 58,
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        // 对应 Ardot `87:419 返回按钮`：38×38 且 fill 全透明，只作触控区。
                        left: 12,
                        top: 14,
                        width: 38,
                        height: 38,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onExit,
                          child: Center(
                            // 对应 Ardot `87:420 返回箭头`：21×21 居中，不撑满触控区。
                            child: Image(
                              image: LiveKitResources.image('livekit_summary_back'),
                              width: 21,
                              height: 21,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 80,
                        right: 80,
                        top: 12,
                        height: 42,
                        child: Center(
                            child: Text(
                          widget.summaryContext.interruptionMessage ??
                              LiveKitResources.localizedString('tuilivekit.pusher.summary.statistics'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 250,
                    child: _buildHeroCard(
                      context: context,
                      timeRange: timeRange,
                      pausedSeconds: pausedSeconds,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 19),
                  child: SizedBox(
                    height: 21,
                    child: Text(
                      LiveKitResources.localizedString('tuilivekit.pusher.summary.session_data'),
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      for (int row = 0; row < (_statCards.length + 1) ~/ 2; row++) ...<Widget>[
                        if (row > 0) const SizedBox(height: 10),
                        SizedBox(
                          height: 88,
                          child: Row(
                            children: <Widget>[
                              for (int column = 0; column < 2; column++) ...<Widget>[
                                if (column > 0) const SizedBox(width: 10),
                                // 两列等分可用宽度，替代原先由 maxWidth 反推的 cardWidth。
                                Expanded(
                                  child: row * 2 + column < _statCards.length
                                      ? _SummaryStatCardView(
                                          title: LiveKitResources.localizedString(
                                              'tuilivekit.pusher.summary.${_statCards[row * 2 + column].$1}'),
                                          unit: LiveKitResources.localizedString(
                                              'tuilivekit.pusher.summary.unit.${_statCards[row * 2 + column].$2}'),
                                          accentColor: _statCards[row * 2 + column].$3,
                                          value: _hasData ? values[row * 2 + column] : null,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({required BuildContext context, required String timeRange, required int pausedSeconds}) {
    final pauseTitle = LiveKitResources.localizedString('tuilivekit.pusher.summary.paused_duration');
    const pauseTitleStyle = TextStyle(
      color: Color(0x7AFFFFFF),
      fontSize: 10,
      decoration: TextDecoration.none,
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: pauseTitle, style: pauseTitleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final pauseTitleWidth = titlePainter.width.ceilToDouble().clamp(54.0, double.infinity);
    titlePainter.dispose();
    return _SummaryGradientCardView(
      isHero: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 13,
            height: 60,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  // UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.08)
                  color: const Color(0x144A9EFF),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 19,
            height: 48,
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // UIColor(red: 0.098, green: 0.243, blue: 0.42, alpha: 1)
                  color: _PusherSummaryStyle.markBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: LiveTheme.brandBlue, width: 1),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x384A9EFF),
                      offset: Offset(0, 8),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Image(
                      image: LiveKitResources.image('livekit_summary_done'),
                      width: 22,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            top: 80,
            height: 27,
            child: Text(
              LiveKitResources.localizedString('tuilivekit.pusher.summary.ended'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 19,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            top: 111,
            height: 16,
            child: Text(
              timeRange,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x73FFFFFF),
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            top: 146,
            height: 14,
            child: Text(
              LiveKitResources.localizedString('tuilivekit.pusher.summary.duration'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0x7AFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            top: 165,
            height: 40,
            child: Text(
              _hasData ? formatDuration(_summary.totalDuration ~/ 1000) : '--',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _PusherSummaryStyle.durationForeground,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
                shadows: <Shadow>[
                  // UIColor(red: 0.29, green: 0.62, blue: 1) opacity 0.34, radius 20
                  Shadow(color: Color(0x574A9EFF), blurRadius: 20),
                ],
              ),
            ),
          ),
          if (pausedSeconds > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 211,
              height: 27,
              child: Center(
                child: Container(
                  width: pauseTitleWidth + 84,
                  height: 27,
                  decoration: BoxDecoration(
                    // UIColor.white.withAlphaComponent(0.045)
                    color: _PusherSummaryStyle.pauseBackground,
                    borderRadius: BorderRadius.circular(13.5),
                  ),
                  foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13.5),
                      border: Border.all(color: _PusherSummaryStyle.pauseBorder)),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 11,
                        top: 7,
                        width: pauseTitleWidth,
                        height: 14,
                        child: Text(
                          pauseTitle,
                          maxLines: 1,
                          style: pauseTitleStyle,
                        ),
                      ),
                      Positioned(
                        right: 11,
                        top: 7,
                        width: 55,
                        height: 14,
                        child: Text(
                          formatDuration(pausedSeconds),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryStatCardView extends StatelessWidget {
  const _SummaryStatCardView({
    required this.title,
    required this.unit,
    required this.accentColor,
    required this.value,
  });

  final String title;
  final String unit;
  final Color accentColor;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return _SummaryGradientCardView(
      isHero: false,
      accentColor: accentColor,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 13,
            top: 13,
            width: 16,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: accentColor.withAlpha(148), blurRadius: 9),
                ],
              ),
            ),
          ),
          Positioned(
            left: 13,
            right: 13,
            top: 26,
            height: 14,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0x7AFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Positioned(
            left: 13,
            right: 13,
            top: 45,
            height: 31,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final text = value == null ? '--' : '${value! < 0 ? 0 : value}';
                const valueStyle = TextStyle(
                  color: _PusherSummaryStyle.valueForeground,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                );
                const unitStyle = TextStyle(
                  color: Color(0x61FFFFFF),
                  fontSize: 10,
                  decoration: TextDecoration.none,
                );
                final painter = TextPainter(
                  text: TextSpan(text: unit, style: unitStyle),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                final available = (constraints.maxWidth - painter.width - 5).clamp(0.0, double.infinity);
                painter.text = TextSpan(text: text, style: valueStyle);
                painter.layout();
                // UILabel shrinks only the value down to half size while
                // preserving the unit. Measure before laying out the row so
                // the same minimum and trailing boundary apply in Flutter.
                final factor = painter.width == 0 ? 1.0 : (available / painter.width).clamp(.5, 1.0);
                painter.dispose();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle.copyWith(fontSize: 23 * factor),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(unit, maxLines: 1, style: unitStyle),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGradientCardView extends StatelessWidget {
  const _SummaryGradientCardView({
    required this.isHero,
    required this.child,
    this.accentColor,
  });

  final bool isHero;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final double radius = isHero ? 22 : 16;
    final Color accent = accentColor ?? LiveTheme.brandBlue;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          // hero: white 0.085；stat: white 0.065
          color: isHero ? const Color(0x16FFFFFF) : const Color(0x11FFFFFF),
          width: 1,
        ),
        boxShadow: isHero
            ? const <BoxShadow>[
                // opacity 0.22, offset (0, 18), radius 42
                BoxShadow(color: Color(0x38000000), offset: Offset(0, 18), blurRadius: 42),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isHero ? Alignment.topCenter : Alignment.centerLeft,
                    end: isHero ? Alignment.bottomCenter : Alignment.centerRight,
                    colors: isHero
                        // white 0.065 → white 0.025
                        ? const <Color>[Color(0x11FFFFFF), Color(0x06FFFFFF)]
                        // white 0.055 → white 0.022
                        : const <Color>[Color(0x0EFFFFFF), Color(0x06FFFFFF)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isHero
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x214A9EFF),
                            Color(0x094A9EFF),
                            Color(0x004A9EFF),
                          ],
                          stops: <double>[0, 0.38, 0.75],
                        )
                      : LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            accent.withAlpha(0),
                            accent.withAlpha(0),
                            accent.withAlpha(22),
                          ],
                          stops: const <double>[0, 0.28, 1],
                        ),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

abstract final class _PusherSummaryStyle {
  static const giftsAccent = Color(0xFFF0BC5F);
  static const giftValueAccent = Color(0xFFFF6E9D);
  static const viewersAccent = Color(0xFF69A8FF);
  static const commentsAccent = Color(0xFFBE83FF);
  static const sendersAccent = Color(0xFF57D5BF);
  static const likesAccent = Color(0xFFFF7B72);
  static const markBackground = Color(0xFF193E6B);
  static const durationForeground = Color(0xFF8ECFFF);
  static const pauseBackground = Color(0x0BFFFFFF);
  static const pauseBorder = Color(0x12FFFFFF);
  static const valueForeground = Color(0xF0FFFFFF);
}

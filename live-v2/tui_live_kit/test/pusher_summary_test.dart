import 'support/listener_probe.dart';
import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_live_uikit/src/common/live_kit_resources.dart';
import 'package:tencent_live_uikit/src/pusher/summary/pusher_summary_view.dart';

class Summary implements LiveSummaryStore, LiveSummaryState {
  @override
  final ValueProbe<LiveSummaryData> summaryData = ValueProbe(LiveSummaryData(
      totalDuration: 65000,
      totalGiftCoins: 51,
      totalGiftUniqueSenders: 3,
      totalGiftsSent: 7,
      totalMessageSent: 11,
      totalViewers: 19,
      totalLikesReceived: 23));
  @override
  LiveSummaryState get liveSummaryState => this;
}

void main() {
  testWidgets(
      'summary fits English pause text and large statistics on narrow screens',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const count = 999999999999;
    for (final width in [320.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(MaterialApp(
        home: PusherSummaryView(
          liveID: 'r',
          summaryContext: PusherSummaryContext(
              startTime: DateTime(2026),
              endTime: DateTime(2026, 1, 1, 1),
              pausedSeconds: 65),
          finalSummary: PusherSummary(
            liveDuration: 75,
            totalViewers: count,
            totalMessageCount: count,
            totalGiftsSent: count,
            totalGiftCoins: count,
            totalUniqueGiftSenders: count,
            totalLikesReceived: count,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final pause = find.text('Paused duration');
      final pauseText = tester.widget<Text>(pause);
      final painter = TextPainter(
        text: TextSpan(text: pauseText.data, style: pauseText.style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(tester.getSize(pause).width, greaterThanOrEqualTo(painter.width));
      painter.dispose();
      final capsule =
          find.ancestor(of: pause, matching: find.byType(Container)).first;
      expect(tester.getSize(capsule).width, tester.getSize(pause).width + 84);
      final values = find.text('$count');
      expect(values, findsNWidgets(6));
      for (final value in values.evaluate()) {
        final finder = find.byElementPredicate((element) => element == value);
        final text = value.widget as Text;
        expect(text.style!.fontSize, inInclusiveRange(11.5, 23));
        expect(text.style!.fontSize, lessThan(23));
        expect(text.maxLines, 1);
        final row = find.ancestor(of: finder, matching: find.byType(Row)).first;
        final texts = find.descendant(of: row, matching: find.byType(Text));
        final unit = texts.last;
        expect(tester.getRect(finder).right + 5,
            lessThanOrEqualTo(tester.getRect(unit).left + .01));
        final card = find
            .ancestor(
                of: finder,
                matching: find.byWidgetPredicate((widget) =>
                    widget.runtimeType.toString() ==
                    '_SummaryGradientCardView'))
            .first;
        expect(tester.getRect(unit).right,
            lessThanOrEqualTo(tester.getRect(card).right - 13 + .01));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'final event snapshot is authoritative and missing data stays unknown',
      (tester) async {
    final context = PusherSummaryContext(
        startTime: DateTime(2026),
        endTime: DateTime(2026, 1, 1, 1),
        pausedSeconds: 0,
        interruptionMessage: 'server ended');
    await tester.pumpWidget(MaterialApp(
        home: PusherSummaryView(liveID: 'r', summaryContext: context)));
    await tester.pumpAndSettle();
    expect(find.text('--'), findsNWidgets(7));
    expect(find.text('server ended'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: PusherSummaryView(
            liveID: 'r',
            summaryContext: context,
            finalSummary: PusherSummary(
                liveDuration: 75, totalViewers: 123, totalMessageCount: 321))));
    await tester.pump();
    expect(find.text('00:01:15'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('321'), findsOneWidget);
    expect(find.text('--'), findsNothing);
  });

  testWidgets('summary observes simulation without changing official data',
      (tester) async {
    final sdk = Summary();
    final debug = SimulationProbe()..setEnabled(true);
    await tester.pumpWidget(MaterialApp(
        home: PusherSummaryView(
            liveID: 'r',
            summaryStore: sdk,
            debugSimulationStore: debug,
            summaryContext: PusherSummaryContext(
                startTime: null, endTime: DateTime(2026), pausedSeconds: 0))));
    debug.addAudience(count: 100);
    await tester.pump();
    expect(find.text('119'), findsOneWidget);
    expect(sdk.summaryData.value.totalViewers, 19);
    debug.setEnabled(false);
    await tester.pump();
    expect(find.text('19'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(debug.isObserved, isFalse);
    debug.dispose();
  });

  testWidgets(
      'summary uses official duration and six counts, retains only time context',
      (tester) async {
    final sdk = Summary();
    await tester.pumpWidget(MaterialApp(
        home: PusherSummaryView(
            liveID: 'r',
            summaryStore: sdk,
            summaryContext: PusherSummaryContext(
                startTime: DateTime(2026, 9, 5, 10),
                endTime: DateTime(2026, 9, 5, 11),
                pausedSeconds: 4))));
    await tester.pumpAndSettle();
    for (final value in [
      '51',
      '3',
      '7',
      '11',
      '19',
      '23',
      '00:01:05',
      '00:00:04',
      '10:00 ~ 11:00'
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(
        find.text(LiveKitResources.localizedString(
            'tuilivekit.pusher.summary.gift_value')),
        findsOneWidget);
    sdk.summaryData.value = LiveSummaryData(totalDuration: 100000);
    await tester.pump();
    expect(find.text('00:01:40'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(sdk.summaryData.isObserved, isFalse);
    expect(tester.takeException(), isNull);
  });
}

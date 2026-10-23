/// Living 底部工具栏：连麦、更多两个入口。
library;

import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../common/live_kit_resources.dart';
import '../../common/theme/live_theme.dart';

class LiveBottomToolbarView extends StatelessWidget {
  const LiveBottomToolbarView({
    super.key,
    this.onCoGuest,
    this.onMore,
    this.moreActionKey,
    this.hasCoGuestUnread = false,
    this.isCoGuestStageActive = false,
  });

  final VoidCallback? onCoGuest;

  final VoidCallback? onMore;

  /// 点赞辅助动画的起点取自"更多"入口。
  final GlobalKey? moreActionKey;

  /// 有未读连麦申请时显示带提示的完整连麦图标。
  final bool hasCoGuestUnread;

  /// 连麦舞台可见时工具栏底色透明。
  final bool isCoGuestStageActive;

  /// UIColor(red: 0.039, green: 0.039, blue: 0.059, alpha: 1)
  static const Color _backgroundColor = Color(0xFF0A0A0F);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isCoGuestStageActive ? const Color(0x00000000) : _backgroundColor,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 12,
            top: 16,
            child: _LivingActionControl(
              title: LiveKitResources.localizedString('tuilivekit.pusher.living.coguest'),
              assetName: hasCoGuestUnread ? 'livekit_living_coguest_unread' : 'livekit_living_coguest',
              iconSize: const Size(46, 38),
              iconTop: -6,
              onPressed: onCoGuest,
            ),
          ),
          Positioned(
            right: 12,
            top: 16,
            child: _LivingActionControl(
              key: moreActionKey,
              title: LiveKitResources.localizedString('tuilivekit.common.more'),
              assetName: 'livekit_living_more',
              iconSize: const Size(27, 27),
              onPressed: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivingActionControl extends StatelessWidget {
  const _LivingActionControl({
    super.key,
    required this.title,
    required this.assetName,
    required this.iconSize,
    this.iconTop = 0,
    this.onPressed,
  });

  final String title;
  final String assetName;
  final Size iconSize;
  final double iconTop;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final titleStyle = LiveTheme.textStyle(LiveTextRole.control, tone: LiveTextTone.secondary);
    final painter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout();
    final width = math.max(34.0, painter.width.ceilToDouble());
    painter.dispose();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: width,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              top: iconTop,
              left: (width - iconSize.width) / 2,
              width: iconSize.width,
              height: iconSize.height,
              child: Image(
                image: LiveKitResources.image(assetName),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              height: 16,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LiveTheme.textStyle(LiveTextRole.control, tone: LiveTextTone.secondary).copyWith(
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0x59000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

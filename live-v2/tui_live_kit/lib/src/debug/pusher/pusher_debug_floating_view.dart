/// 铺满容器的调试层：只有悬浮按钮可点（未展开面板时不拦截舞台手势），
/// 按钮可拖动并吸边，点击后上滑呈现 `PusherDebugPanelView`。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pusher_debug_panel_view.dart';
import 'pusher_debug_gift_store.dart';
import 'pusher_debug_simulation_store.dart';

class PusherDebugFloatingView extends StatefulWidget {
  const PusherDebugFloatingView({
    super.key,
    required this.store,
    this.giftStore,
  });

  final PusherDebugSimulationStore store;

  final PusherDebugGiftStore? giftStore;

  @override
  State<PusherDebugFloatingView> createState() =>
      _PusherDebugFloatingViewState();
}

class _PusherDebugFloatingViewState extends State<PusherDebugFloatingView>
    with SingleTickerProviderStateMixin {
  static const double _inset = 38;
  static const double _buttonSize = 52;
  static const double _preferredPanelHeight = 590;

  Offset? _buttonCenter;
  Offset _dragStartCenter = Offset.zero;
  bool _isDragging = false;
  bool _isPanelPresented = false;
  bool _isDismissing = false;
  int _refreshToken = 0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPanel() {
    if (_isPanelPresented) {
      return;
    }
    setState(() {
      _isPanelPresented = true;
      _refreshToken += 1;
    });
    _controller.forward();
  }

  Future<void> _dismissPanel() async {
    if (!_isPanelPresented || _isDismissing) return;
    _isDismissing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await _controller.reverse().orCancel;
      if (mounted) setState(() => _isPanelPresented = false);
    } on TickerCanceled {
      // Removing the stage also removes this animation owner.
    } finally {
      _isDismissing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final EdgeInsets padding = mediaQuery.padding;
    // 承载页已关闭 Scaffold 的键盘避让（与 iOS 全屏 VC 一致），调试面板自行抬高。
    final double bottomInset =
        math.max(padding.bottom, mediaQuery.viewInsets.bottom);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        // 右侧 38、垂直居中。
        final Offset center = _clamped(
            _buttonCenter ?? Offset(size.width - _inset, size.height / 2),
            size,
            padding);
        final double panelHeight = _panelHeight(size, padding, bottomInset);

        return AnimatedBuilder(
          animation: _progress,
          builder: (BuildContext context, Widget? child) {
            final double value = _progress.value;
            return Stack(
              children: <Widget>[
                if (_isPanelPresented)
                  Positioned.fill(
                    child: Opacity(
                      opacity: value,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissPanel,
                        child: const ColoredBox(
                            color: Color.fromRGBO(0, 0, 0, 0.18)),
                      ),
                    ),
                  ),
                Positioned(
                  key: const ValueKey('debug-panel'),
                  left: 8,
                  right: 8,
                  bottom: bottomInset + 8,
                  height: panelHeight,
                  child: Offstage(
                    offstage: !_isPanelPresented,
                    child: Transform.translate(
                      offset: Offset(0, panelHeight * (1 - value)),
                      child: PusherDebugPanelView(
                        store: widget.store,
                        giftStore: widget.giftStore,
                        refreshToken: _refreshToken,
                        onClose: _dismissPanel,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: Duration(milliseconds: _isDragging ? 0 : 220),
                  curve: Curves.easeOut,
                  left: center.dx - _buttonSize / 2,
                  top: center.dy - _buttonSize / 2,
                  width: _buttonSize,
                  height: _buttonSize,
                  child: IgnorePointer(
                    ignoring: _isPanelPresented,
                    child: Opacity(
                        opacity: 1 - value,
                        child: _buildFloatingButton(size, padding)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingButton(Size size, EdgeInsets padding) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showPanel,
      onPanStart: (DragStartDetails details) {
        setState(() {
          _isDragging = true;
          _dragStartCenter = _clamped(
              _buttonCenter ?? Offset(size.width - _inset, size.height / 2),
              size,
              padding);
          _buttonCenter = _dragStartCenter;
        });
      },
      onPanUpdate: (DragUpdateDetails details) {
        setState(() {
          _buttonCenter = _clamped(
            Offset(_buttonCenter!.dx + details.delta.dx,
                _buttonCenter!.dy + details.delta.dy),
            size,
            padding,
          );
        });
      },
      onPanEnd: (DragEndDetails details) {
        final Offset current =
            _clamped(_buttonCenter ?? _dragStartCenter, size, padding);
        final double edgeX =
            current.dx < size.width / 2 ? _inset : size.width - _inset;
        setState(() {
          _isDragging = false;
          _buttonCenter = Offset(edgeX, current.dy);
        });
      },
      onPanCancel: () {
        final Offset current =
            _clamped(_buttonCenter ?? _dragStartCenter, size, padding);
        final double edgeX =
            current.dx < size.width / 2 ? _inset : size.width - _inset;
        setState(() {
          _isDragging = false;
          _buttonCenter = Offset(edgeX, current.dy);
        });
      },
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, 0.58),
          borderRadius: BorderRadius.all(Radius.circular(26)),
          border: Border.fromBorderSide(
            BorderSide(color: Color.fromRGBO(255, 255, 255, 0.28)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.32),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'DEBUG',
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.92),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  double _panelHeight(Size size, EdgeInsets padding, double bottomInset) {
    final double available =
        size.height - (padding.top + 52) - (bottomInset + 8);
    return available.clamp(0, _preferredPanelHeight);
  }

  Offset _clamped(Offset point, Size size, EdgeInsets padding) {
    final double minimumY = padding.top + _inset;
    final double bottomLimit = size.height - padding.bottom - 88 - _inset;
    final double maximumY = bottomLimit > minimumY ? bottomLimit : minimumY;
    final double maximumX =
        size.width - _inset > _inset ? size.width - _inset : _inset;
    final double x = point.dx < _inset
        ? _inset
        : (point.dx > maximumX ? maximumX : point.dx);
    final double y = point.dy < minimumY
        ? minimumY
        : (point.dy > maximumY ? maximumY : point.dy);
    return Offset(x, y);
  }
}

import 'package:flutter/widgets.dart';
import 'pusher_debug_support.dart';
import '../../pusher/pusher_view.dart';

mixin PusherViewDebug on State<PusherView> {
  final PusherDebugSupport debugSupport = PusherDebugSupport();
  final _debugChanges = ValueNotifier<int>(0);
  void onDebugPresentationChanged();

  void bindDebugSupport() {
    debugSupport.bind(onNeedsRender: () {
      if (!mounted) return;
      onDebugPresentationChanged();
      _debugChanges.value++;
    });
    debugSupport.setEnabled(widget.isDebugSimulationEnabled);
  }

  PusherPresentationState debugDisplayState(PusherPresentationState state) =>
      debugSupport.transform(state);
  Widget buildDebugLayer() => ValueListenableBuilder<int>(
      valueListenable: _debugChanges,
      builder: (context, _, child) => debugSupport.install());

  @override
  void didUpdateWidget(PusherView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDebugSimulationEnabled != widget.isDebugSimulationEnabled) {
      debugSupport.setEnabled(widget.isDebugSimulationEnabled);
    }
  }

  @override
  void dispose() {
    debugSupport.dispose();
    _debugChanges.dispose();
    super.dispose();
  }
}

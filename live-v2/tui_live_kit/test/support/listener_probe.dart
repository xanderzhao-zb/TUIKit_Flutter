import 'package:flutter/foundation.dart';
import 'package:tencent_live_uikit/src/debug/pusher/pusher_debug_simulation_store.dart';

class ValueProbe<T> extends ValueNotifier<T> {
  ValueProbe(super.value);
  bool get isObserved => hasListeners;
}

class SimulationProbe extends PusherDebugSimulationStore {
  bool get isObserved => hasListeners;
}

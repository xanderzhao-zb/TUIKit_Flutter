/// Debug 礼物模拟数据源：只提供本地礼物素材与选中态，
/// 不调用任何礼物 SDK 接口，也不影响真实收礼统计。
library;

import 'package:flutter/foundation.dart';

import '../../common/gift/display/gift_display_view.dart';
import '../../common/live_kit_resources.dart';

@immutable
class PusherDebugGiftResource {
  const PusherDebugGiftResource({
    required this.giftID,
    required this.name,
    required this.iconURL,
    required this.resourceURL,
    required this.coins,
  });

  final String giftID;
  final String name;
  final String iconURL;
  final String resourceURL;
  final int coins;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PusherDebugGiftResource &&
        other.giftID == giftID &&
        other.name == name &&
        other.iconURL == iconURL &&
        other.resourceURL == resourceURL &&
        other.coins == coins;
  }

  @override
  int get hashCode => Object.hash(giftID, name, iconURL, resourceURL, coins);
}

class PusherDebugGiftStore {
  PusherDebugGiftStore() {
    gifts = _fixtures;
    _selectedGiftID = gifts.isEmpty ? null : gifts.first.giftID;
  }

  VoidCallback? onStateChanged;

  late final List<PusherDebugGiftResource> gifts;

  String? get selectedGiftID => _selectedGiftID;
  String? _selectedGiftID;

  /// 记录最近一次真实收礼，便于对照自查。
  GiftDisplayItem? get lastRealGift => _lastRealGift;
  GiftDisplayItem? _lastRealGift;

  PusherDebugGiftResource? get selectedGift {
    for (final PusherDebugGiftResource gift in gifts) {
      if (gift.giftID == _selectedGiftID) {
        return gift;
      }
    }
    return null;
  }

  void selectGift(String id) {
    final bool exists = gifts.any(
      (PusherDebugGiftResource gift) => gift.giftID == id,
    );
    if (!exists || _selectedGiftID == id) {
      return;
    }
    _selectedGiftID = id;
    onStateChanged?.call();
  }

  void recordRealGift(GiftDisplayItem gift) {
    _lastRealGift = gift;
    onStateChanged?.call();
  }

  void deactivate() {
    _selectedGiftID = gifts.isEmpty ? null : gifts.first.giftID;
  }

  static const String _staticImageBase =
      'https://liteav.sdk.qcloud.com/app/res/picture/live/gift/';
  static const String _animatedBase =
      'https://dldir1.qq.com/hudongzhibo/TRTC/TUIKit/Gift/svga/';

  static List<PusherDebugGiftResource> get _fixtures =>
      <PusherDebugGiftResource>[
        PusherDebugGiftResource(
          giftID: 'debug_rocket',
          name: LiveKitResources.localizedString(
              'tuilivekit.debug.gift.name.rocket'),
          iconURL: '${_staticImageBase}huojian.png',
          resourceURL: '',
          coins: 99,
        ),
        PusherDebugGiftResource(
          giftID: 'debug_egg',
          name: LiveKitResources.localizedString(
              'tuilivekit.debug.gift.name.egg'),
          iconURL: '${_staticImageBase}jidan.png',
          resourceURL: '',
          coins: 99,
        ),
        PusherDebugGiftResource(
          giftID: 'debug_kiss',
          name: LiveKitResources.localizedString(
              'tuilivekit.debug.gift.name.kiss'),
          iconURL: '${_staticImageBase}kiss.png',
          resourceURL: '',
          coins: 99,
        ),
        PusherDebugGiftResource(
          giftID: 'debug_sports_car',
          name:
              "${LiveKitResources.localizedString('tuilivekit.debug.gift.name.sports_car')} · SVGA",
          iconURL: '${_animatedBase}sports_car.png',
          resourceURL: '${_animatedBase}sports_car.svga',
          coins: 399,
        ),
        PusherDebugGiftResource(
          giftID: 'debug_magic_cat',
          name:
              "${LiveKitResources.localizedString('tuilivekit.debug.gift.name.magic_cat')} · SVGA",
          iconURL: '${_animatedBase}cat.png',
          resourceURL: '${_animatedBase}cat.svga',
          coins: 299,
        ),
        PusherDebugGiftResource(
          giftID: 'debug_luxury_car',
          name:
              "${LiveKitResources.localizedString('tuilivekit.debug.gift.name.luxury_car')} · SVGA",
          iconURL: '${_animatedBase}car.png',
          resourceURL: '${_animatedBase}car.svga',
          coins: 199,
        ),
      ];
}

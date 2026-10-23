import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_effect_player/ftceffect_player.dart';

import 'generate_test_user_sig.dart';

/// 提交 MP4 特效授权；Future 完成只表示调用已提交，最终结果由回调给出。
/// 启动和成功登录后均可调用，让首次联网前失败的授权有机会重新发起。
Future<void> initializeEffectLicense() async {
  try {
    await FTCMediaXBase.instance.setLicense(
      GenerateTestUserSig.tencentEffectLicenseURL,
      GenerateTestUserSig.tencentEffectLicenseKey,
      (code, _) {
        // 只记录结果码，不输出 License URL、Key 或原生错误详情。
        debugPrint('[LiveKitAccess][EffectLicense] result=$code');
      },
    );
  } on Object catch (error) {
    final code = error is PlatformException ? error.code : error.runtimeType;
    debugPrint('[LiveKitAccess][EffectLicense] submit failed: $code');
  }
}

Pod::Spec.new do |s|
  s.name             = 'tui_live_kit'
  s.version          = '0.0.1'
  s.summary          = 'TUILiveKit Flutter 组件库的 iOS 承载层。'
  s.description      = <<-DESC
只封装 AtomicXCore 未覆盖、且当前产品范围实际需要的系统能力（当前为系统热状态）。
                       DESC
  s.homepage         = 'https://trtc.io/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tencent' => 'trtc@tencent.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # MP4 礼物的独立授权库；宿主 Podfile 必须指定 MediaX 官方 podspec 来源。
  s.dependency 'YTCommonXMagic', '1.3.1'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

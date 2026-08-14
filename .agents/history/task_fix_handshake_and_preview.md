# 任务清单

- [x] 1. 解决屏幕共享时 BroadcastExtension 出现 `Handshake Failed` 的问题
  - [x] 将 `rtc.startScreenCapture()` 从等待接收端连接的 `recall()` 方法中提前到 `start()` 方法中。
  - [x] 确保在用户点击“开始直播”前，主 App 的 `SocketServer` 已经在后台监听，以便扩展程序能够成功连接。
- [x] 2. 解决 Mac 模拟环境下本地摄像头预览黑屏的问题
  - [x] 废弃存在兼容性问题的 `CameraPreview` (`AVCaptureVideoPreviewLayer`)。
  - [x] 在 `BroadcastViewModel` 中直接暴露底层 WebRTC 生成的 `RTCVideoTrack`。
  - [x] 使用极其稳定的 WebRTC 官方渲染器包装类 `VideoStreamView` (`RTCMTLVideoView`) 进行本地画面的直连渲染。
- [x] 3. 移除屏幕录制时的英文提示名称 `CastNow Screen Share`
  - [x] 将 Native 和 Pro 两个版本的 `BroadcastExtension/Info.plist` 中的 `CFBundleDisplayName` 和 `CFBundleName` 全部修改为与主 App 一致的标准中文名 `即刻投屏`。
- [x] 4. 修复 Web 端断开时，APP 本端未自动退出预览页的问题
  - [x] 在 `rtcConnectStateChanged` 方法中补充状态监听。如果 WebRTC 状态由已连接变为未连接，主动触发 `onDisconnect` 回调，彻底解决了 WebRTC 断开和 PeerJS 断开事件到达时间差造成的状态失效竞态问题。
- [x] 5. 修复 Xcode 关于 `RPSystemBroadcastPickerView` 破坏 SwiftUI 视图层级的警告
  - [x] 移除了直接向 `UIHostingController.view` 强制 `addSubview` 的做法。
  - [x] 使用 `UIViewRepresentable` 将系统录屏组件包装成 SwiftUI 原生支持的 `SystemBroadcastPickerView`，通过 `@Published` 状态触发隐式点击。

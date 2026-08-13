# 问题修复

## 1. 修复APP首次启动摄像头无预览问题
**为什么修改**：
在APP首次启动时，如果没有摄像头权限，系统会异步请求权限。而原有代码中直接调用了 `capturer.startCapture`，此时由于权限尚未授予，iOS 阻塞了硬件数据流。
- **为什么 WEB 端有视频**：WebRTC 底层（`RTCCameraVideoCapturer`）非常健壮，它提前配置好了 `AVCaptureSession` 和数据输出回调。当您点击“同意”授权后，iOS 硬件通道打通，摄像头开始输出视频帧，WebRTC 接收到帧后立刻发送给了 WEB 端。
- **为什么 APP 端无预览**：APP 本地使用的是 `AVCaptureVideoPreviewLayer` 来渲染画面。在没有权限时，该图层被绑定到了一个被系统阻塞的 Session 上，底层渲染管线未能成功建立。当授权通过后，虽然 Session 恢复了数据流动，但 `AVCaptureVideoPreviewLayer` 并未自动刷新/重建其渲染管线，从而导致本地呈现黑屏。

**怎么修改**：
在 `apps/mobile_ios_native/Sources/WebRTC/CameraCapture.swift` 中修改 `start()` 方法：
- 调用前首先检查 `AVCaptureDevice.authorizationStatus(for: .video)` 的权限状态。
- 若状态为 `.notDetermined`，则主动调用 `AVCaptureDevice.requestAccess`，在用户授权通过后的回调中再执行 `startInternal()`。
- 若已授权则直接启动，从而保证在拿到权限后能够正确加载预览。

## 2. 修复 Xcode 编译警告
**为什么修改**：
- `allowBluetooth` 在 iOS 8.0 中被弃用。
- Starscream 中的 `SecTrustEvaluate` 等方法由于 iOS 13 弃用而产生警告；`Metal.xctoolchain` 路径找不到的警告大多由 CocoaPods 第三方库的 Search Paths 引起。为了保持工程干净，需要修复和静默这些不再适用的警告。

**怎么修改**：
- **WebRTCManager.swift 警告**：
  修改 `apps/mobile_ios_native/Sources/WebRTC/WebRTCManager.swift`，将 `.allowBluetooth` 替换为新的 `.allowBluetoothHFP`。
- **Starscream 及第三方库警告**：
  修改 `apps/mobile_ios_native/Podfile`，在 target 'CastNow' 下方添加 `inhibit_all_warnings!`。这将会静默屏蔽所有 CocoaPods 引入的第三方库的编译警告。
  并执行了 `pod install` 更新 Xcode 工程配置。

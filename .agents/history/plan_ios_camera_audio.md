# 修复 iOS 摄像头卡顿与远程音频播放问题 (Implementation Plan)

针对您提出的两个核心问题，经过排查分析，以下是具体的实现方案：

## 1. 修复：选择摄像头时，启动界面卡住
**原因分析**：目前在 `CameraCapture.swift` 中，摄像头的初始化和配置（例如 `captureSession.beginConfiguration()` 等操作）是在主线程中同步执行的。这些底层的 AVFoundation 硬件调用极其耗时，导致了明显的 UI 卡顿，这确实会在审核中被苹果拒审。
**解决方案**：
* 废弃手工控制 `AVCaptureSession` 的实现方式。
* 引入 WebRTC 官方专门针对 iOS 深度优化的类 `RTCCameraVideoCapturer`。它内部会自动在后台线程优雅地处理硬件初始化、帧格式转换和设备旋转，不会有任何卡顿。
* 我们依然可以通过暴露 `capturer.captureSession`，来给 SwiftUI 的 `CameraPreview` 组件提供本地预览流，做到 UI 和推流的完美融合。

## 2. 修复：Web 麦克风在 iOS 没声音
**原因分析**：这是因为 iOS 对音频通道有严格的管控机制。目前的实现中，虽然 WebRTC 成功接收到了音频流，但是没有配置全局的 `RTCAudioSession`，导致系统默认将声音输出到了**听筒**（像打电话一样）而不是外放的**扬声器**（Speaker），或者直接因为权限静音了。
**解决方案**：
* 在 `WebRTCManager.swift` 中增加音频通道的配置逻辑。
* 调用 `RTCAudioSession.sharedInstance()`，将音频模式设置为 `playAndRecord`，并且强制开启 `defaultToSpeaker` 参数，确保不论是媒体播放还是通话声音，都会清晰地从手机底部的扬声器外放出来。

## 3. 修复：摄像头画面在 Web 端不显示
**原因分析**：目前手工捕获和组装 `RTCVideoFrame` 的方式，硬编码了视频的旋转角度（`._0`），且没有对不同的设备像素格式进行严格的兼容。导致 WebRTC 的 C++ 底层编码器可能无法识别这些帧并丢弃了。
**解决方案**：
* 与第 1 点协同解决，使用官方 `RTCCameraVideoCapturer` 后，它会自动将 iOS 相机的原生格式正确地转码为 WebRTC 兼容的帧，推流到 Web 端的画面不仅能正常显示，还会自动适应手机横竖屏的方向。

---
## 附加修复：Web 端断开连接报错
* **问题**：`ReferenceError: resetApp is not defined`
* **解决方案**：在 `App.vue` 调用 `startReceiverPeer` 时，补全第五个参数 `resetApp` 函数传递。

# 任务清单

- [x] 1. 修复APP首次启动时摄像头无预览问题。
  - [x] 在 `CameraCapture.swift` 中增加摄像头权限判断。
  - [x] 未授权时主动申请权限，授权通过后再启动 `capturer.startCapture`。
- [x] 2. 修复 Xcode 编译警告。
  - [x] 将 `WebRTCManager.swift` 中的 `allowBluetooth` 修改为 `.allowBluetoothHFP`。
  - [x] 在 `Podfile` 中添加 `inhibit_all_warnings!` 来静默 CocoaPods 第三方库（Starscream 等）带来的警告。
  - [x] 重新执行 `pod install` 应用配置。

# iOS 端投屏崩溃深度修复记录 (Metal Texture Size Bug)

## 修复总结
彻底解决了 iOS APP 在模拟器上运行接收 5K/4K 视频流时，由于 `MTLTextureDescriptor` 分配异常过大的纹理（15360x8640）而导致 `SIGABRT` 崩溃，并且修复了随之产生的 Main Thread Checker 多线程违规。

## 详细修复项

### 1. 修复 WebRTC 与 SwiftUI 的 Intrinsic Size 爆炸
**现象**：Web 端传来的原生视频为 5120x2880。WebRTC 的 `RTCMTLVideoView` 默认把自己的 `intrinsicContentSize` 设为 `5120x2880`。SwiftUI 尊重了这个固有大小，强制给 Metal 画布分配了巨大的真实 UI 边界。
**修复**：在 `VideoStreamView.swift` 的 `VideoViewWrapper` 中重写 `intrinsicContentSize` 为 `noIntrinsicMetric`，强制 SwiftUI 将其约束在手机屏幕（如 393x852）内，切断了爆炸式画布放大。

### 2. 绕过 WebRTC 底层的 contentScaleFactor 乘法陷阱
**现象**：由于 WebRTC 源码在接收 `setSize` 尺寸时，默认乘以了设备屏幕缩放比例 `UIScreen.main.scale`（在 iPhone Pro 上为 3），导致 5120 被暴涨到 15360，超出了 Metal 硬件最高支持的 8192 纹理限制。
**修复**：在传入 `setSize:` 前，主动将收到的 WebRTC 物理像素除以 `scale`（转换回逻辑点 Points），使得 WebRTC 底层乘以 scale 之后刚好恢复成原生的真实像素，既完美防崩溃，又保持了原生超清画质。

### 3. 修复 Main Thread Checker 后台线程读 UI 属性
**现象**：原先的防崩溃逻辑在 `IncomingVideoStream` 后台队列里读取了 `bounds` 等 UIKit 专有属性，造成卡死和断言失败。
**修复**：使用 `NSLock` 引入了一个线程安全的 `isReadyToRender` 状态位，在主线程 `layoutSubviews` 期间安全更新该状态，后台队列只读该状态不触碰 UI 组件本身。

### 4. 增加了游离态 MTKView 幽灵图层暂停机制
**现象**：在退房或视图解绑时，如果 `isEnabled = false` 没有从底层暂停 `MTKView`，它仍会由于生命周期不一致引发定时器轮询报错。
**修复**：通过遍历 `subviews` 寻找真实的 `MTKView` 并强制设置 `mtkView.isPaused = true`，连根拔起阻断定时器。

### 5. Web端（发送端）增加硬件降级
**修复**：考虑到 15K/5K 的码流会撑爆普通设备的网络，我们在 `useWebRTC.js` 和 `useMediaStream.js` 的 `getDisplayMedia` 处添加了针对 Retina 高分屏的强制缩放保护：如果原始物理像素过大（如 5120），主动通过 `scaleResolutionDownBy` 进行硬件下采样，以降低两端压力。

## 验证结论
*   **编译平台**: Xcode 17, iOS 15.6+ 模拟器 (iPhone 17 Pro)
*   **测试场景**: 从带有 Retina 5K 屏幕的 Mac 向 iOS 模拟器发送高帧率屏幕共享
*   **验证结果**: 彻底告别 SIGABRT 崩溃，画面无变形（完全保留 aspectFit），进出房间丝滑稳定。

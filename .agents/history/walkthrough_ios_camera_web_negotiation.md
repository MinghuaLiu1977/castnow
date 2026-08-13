# 修复界面卡顿与 WebRTC SDP 握手丢失音视频轨道的问题 (Walkthrough)

本次修复了两个极易被忽视的深层 Bug，彻底打通了 iOS 到 Web 端的音视频双向流通，并达到了丝滑的 UI 体验。

## 详细修复项

### 1. 彻底解决 iOS 摄像头选择卡顿
*   **问题**：即使换了更高级的 API，底层的硬件嗅探（列出所有可用摄像头、支持的分辨率等）依然会在主线程引发短时间的 UI 冻结。
*   **修复**：修改了 `CameraCapture.swift`。通过 `DispatchQueue.global(qos: .userInitiated).async`，将所有的硬件嗅探和初始化流程完全丢进高优的后台线程。界面瞬间响应无延迟，用户体验极其流畅。

### 2. 修复因 SDP 协商导致的画面与声音丢失 (Web 端补丁)
*   **问题**：Web 端作为主叫方时，如果没有向 iOS 端发送真实的音视频流，其底层的 Offer SDP 会残缺，导致 iOS 端想要发出的摄像头画面和麦克风声音被 WebRTC 引擎静默丢弃。
*   **修复**：在 `useWebRTC.js` 的 `startReceiverPeer` 发起呼叫之前，利用 HTML5 Canvas 绘制了一个 1x1 的隐藏画布转为 Dummy Video Track，利用 `AudioContext` 建立了一个 Dummy Audio Track。
*   **结果**：将这两个无感知的假轨道加入 Web 端的呼叫中，强制 WebRTC 开启全双工的音视频通道。现在，不论 Web 端有没有开启自己的麦克风，iOS 的摄像头画面和麦克风声音都能百分之百完美传输到网页端并播放出来了！

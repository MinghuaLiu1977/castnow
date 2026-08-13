# 修复界面卡顿与 WebRTC SDP 握手丢失音视频轨道的问题 (Implementation Plan)

## 1. 修复：启动投屏进入界面依旧会卡顿
**原因分析**：尽管之前切换到了 `RTCCameraVideoCapturer` 避免了手动操作，但是在 `start()` 方法中，调用 `RTCCameraVideoCapturer.captureDevices()` 和格式遍历去查询硬件支持时，依然是在主线程中同步执行的。这些底层的硬件嗅探（Hardware Probing）操作极其耗时，导致了界面卡住的现象。
**解决方案**：
* 将 `CameraCapture.swift` 的整个 `start()` 逻辑（包括硬件查询、格式排序、启动捕获）全部放入 `DispatchQueue.global(qos: .userInitiated).async` 后台线程中执行。
* 只有当启动成功或失败时，才切回主线程调用 `onStarted` 回调更新 UI 状态，彻底消除主线程的任何阻塞。

## 2. 修复：Web 端始终没有 iOS 摄像头画面，麦克风声音也传不过去
**原因分析**：这是一个经典的 WebRTC SDP 协商（握手）陷阱。
在当前的架构下，是由 Web 端主动向 iOS 发起呼叫（Call）产生 Offer 的。而 Web 端在发起呼叫时，如果没有开启麦克风（甚至完全没有音视频流），Chrome 浏览器生成的 SDP Offer 里**根本不会包含 `m=audio` 和 `m=video` 的字段**。
根据 WebRTC 的协议，如果 Caller（Web端）没有申请视频和音频通道，Callee（iOS端）在生成 Answer 时就算主动加入了摄像头和麦克风轨道，也会被底层引擎直接抛弃！这就导致了只要 Web 端没送音视频流过去，iOS 的音视频流也绝对送不回来。
**解决方案**：
* 欺骗底层 WebRTC 引擎：在 `useWebRTC.js` 中，当发起 `peer.call()` 时，我们动态用 HTML5 Canvas 凭空捏造一个 1x1 像素的虚拟视频流，再用 Web Audio API 捏造一个静音的虚拟音频流。
* 把这两个“假流”塞进 Web 端的呼叫请求中。这样生成的 Offer 就完美包含了音视频的申请许可。
* iOS 端收到带有许可的 Offer 后，就能顺理成章地将真实的摄像头画面和真实的麦克风声音通过 Answer 传回给 Web 端了！且那个 1x1 的假流在 iOS 端会被直接丢弃，无任何副作用。

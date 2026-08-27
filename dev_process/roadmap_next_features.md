# CastNow 下一步功能规划路线图 (Roadmap)

## 一、背景与现状回顾

### 1.1 近期演进与 Review 总结
- **架构转型**：完成从 Flutter Pro/Standard 双版本到 **纯原生 iOS (Swift + WebRTC native) + Web (Vue 3)** 架构的重构，解决了 ReplayKit Broadcast Extension 50MB 内存上限及复杂生命周期问题。
- **审核合规 (Guideline 2.5.4)**：明确了“屏幕分享 + 摄像头视频 + 双向实时语音对讲 (Two-way Intercom)”的后台音频使用合规链路。
- **稳定性加固**：
  - 修复了 Extension 本地 Socket 发送阻塞导致的 ReplayKit 超时崩溃（增加 isSending 非阻塞丢帧保护与动态缓冲）。
  - 修复了 WebRTC Audio Track 重复添加导致 SDP 协商混乱和双向语音不通的问题。
  - 实现了 Web 端与 iOS 端双语（中/英）支持。

---

## 二、下一步功能规划（4 大演进维度）

### 阶段一：多源流体验闭环与布局深化（优先级：P0，核心体验）

#### 1. 接收端灵活布局（Web 端 & iOS 接收端）
- **画中画 (PiP) 进阶交互**：
  - 小窗支持自由拖拽（Drag & Drop）与四角磁吸贴边吸附。
  - 双击小窗或点击快捷悬浮按钮，实现主副画面**无缝层级切换 (Swap)**。
  - 小窗支持尺寸缩放调节。
- **并排分屏模式 (Side-by-Side / Split View)**：
  - 屏幕流与摄像头流 1:1 或 4:3 等比例并排展示，适合线上会议与网课场景。
- **热插拔流切换 (Dynamic Track Renegotiation)**：
  - 发送端在投屏进行中，可以随时开启/关闭摄像头或麦克风，无需挂断重连即可动态增减媒体轨道。

---

### 阶段二：传输质量与网络自适应优化（优先级：P1，技术壁垒）

#### 1. 弱网自适应与 QoS 拥塞控制
- **场景化预设模式**：
  - **清晰度优先模式（办公/文档/网课）**：高分辨率（1080P/2K/4K）、高文字边缘锐度，容忍适度帧率下降（15~20fps）。
  - **流畅度优先模式（游戏/动态视频）**：锁定 30~60fps，启用自适应降分辨率与降码率，确保毫秒级极低延迟。
- **动态帧率与丢帧恢复**：
  - 结合 WebRTC BWE (Bandwidth Estimation) 反馈，动态调节 BroadcastExtension 捕获采样间隔，避免积压。
- **连接状态实时监控 HUD**：
  - 接收端支持开启调试覆盖层（实时 RTT 延迟、当前码率 Bitrate、丢包率 Packet Loss、当前编码格式 VP8/H.264）。

---

### 阶段三：协作与互动能力增强（优先级：P1，产品价值）

#### 1. 基于 WebRTC DataChannel 的实时协作
- **远程激光笔 (Laser Pointer)**：
  - 接收端或发送端可以在画面上移动激光红点，另一端以极低延迟实时同步显示轨迹。
- **屏幕涂鸦标注 (Annotation / Whiteboard Overlay)**：
  - 讲解时可在屏幕上画圈、下划线、绘制箭头，支持一键清屏与自动淡出。
- **Web 端录制与高清截图**：
  - 基于浏览器的 MediaRecorder API 实现接收端一键高清录屏，直接下载 WebM/MP4 文件；支持一键抓拍当前原画帧并保存 PNG。

#### 2. 安全与准入控制
- **房间准入安全码**：
  - 发送端可选择是否开启“连接确认弹窗”或“4位访问密码”，防止误投或未授权接入。

---

### 阶段四：生态扩展与局域网无感发现（优先级：P2，生态布局）

#### 1. 局域网免配对发现 (Local Network Auto-Discovery)
- **Bonjour / mDNS 探测**：
  - 处于同一 Wi-Fi 局域网下的接收端与发送端，自动在列表列出可用设备，点击即可发起投屏，无需手动输入 6 位配对码。
- **本地 ICE Candidate 优先直连**：
  - 局域网内完全绕过公网 STUN/TURN，实现 10ms 级别的局域网超低延迟镜像。

---

## 四、技术实施与架构建议

1. **模块化与解耦**：
   - Web 端：将 WebRTC 逻辑、Overlay 布局管理器（PiP/Side-by-Side）、DataChannel 协作层（激光笔/涂鸦）拆分为独立的 Composable 与 Component。
   - iOS 原生端：将媒体采集管理、Socket 缓冲区、WebRTC 控制器、UI 画布严格分离，保持单向数据流。
2. **测试驱动 (TDD / Unit Tests)**：
   - 每个新功能模块配套自动化单元测试（Web 端 Vitest / Jest，iOS 端 XCTest），覆盖状态切换与布局边界条件。

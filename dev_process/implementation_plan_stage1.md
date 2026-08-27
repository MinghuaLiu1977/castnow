# 实施方案：阶段一 多源流体验闭环与灵活布局 (v3.0.0)

本方案旨在全面落地 PRD 规划中的**多源流同步传输**与**接收端自定义布局管理**，涵盖 Web 端与 iOS 原生端的核心体验闭环。

---

## 一、用户审核项

> [!IMPORTANT]
> **多源流并发资源考量**：在 iOS 设备上同时开启“系统屏幕投屏”与“本地摄像头采集”时，将同时运行 ReplayKit socket 捕获与 AVCaptureSession。我们已针对硬编硬解和内存做了防溢出优化，但在极低端老旧机型上发热量会有所增加。
> **双向交互体验**：接收端在画中画 (PiP) 模式下支持自由拖拽与松手自动四角磁吸，双击小窗即可毫秒级无缝 Swap 主副流。

---

## 二、拟议变更详细设计

### 1. Web 端 (Vue 3)
#### [MODIFY] [useLayout.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/composables/useLayout.js)
- **智能磁吸贴边 (Snap to Edge/Corner)**：在拖拽结束 `handleDragEnd` 时，根据窗口宽高与 PiP 尺寸，自动将小窗吸附到最近的四角（左上、右上、左下、右下），并保留安全间距 padding。
- **边界约束 (Bounds Clamping)**：在 `handleDragMove` 中限制 `pipPosition` 不可超出屏幕视口边界。
- **小窗交互增强**：提供 `snapToCorner(corner)` 方法便于快捷贴角，支持设置 PiP 比例。

#### [MODIFY] [App.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/App.vue)
- **双击小窗 Swap**：在 PiP 小窗口上增加 `@dblclick="swapStreams"` 与触摸双击识别。
- **悬浮操作工具栏**：在 PiP 悬浮窗右上角提供“切换主副窗 Swap”与“贴角对齐”快捷图标。
- **平滑动画优化**：在松手吸附阶段添加 cubic-bezier 平滑过渡动画，拖拽时保持 0 延迟响应。

#### [NEW] [layout.test.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/layout.test.js)
- 编写对于 `useLayout` 磁吸算法、边界限制、Swap 切换、Side-by-side 比例调整的单元测试。

---

### 2. iOS 原生端 (mobile_ios_native)

#### [MODIFY] [SourceSelectView.swift](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_ios_native/Sources/UI/SourceSelectView.swift)
- 解除屏幕 (`shareScreen`) 与摄像头 (`shareCamera`) 之间的 `exclusive: true` 互斥逻辑，允许用户同时勾选“屏幕 + 摄像头 + 麦克风”。
- 只要至少选中一个视频源（屏幕或摄像头），即可点击启动投屏。

#### [MODIFY] [BroadcastView.swift](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_ios_native/Sources/UI/BroadcastView.swift)
- **多流采集与注册**：
  - 当 `shareScreen && shareCamera` 时，同时启动 `SocketVideoCapturer` 与 `CameraCapture`。
  - 在 `recall(to:)` 中，将屏幕轨与摄像头轨同时通过 `rtc.attachBroadcastTrack` 注册并发送。
- **发送端本地画中画预览**：
  - 当双流同时开启时，发送端界面展示屏幕预览（大图）并在右下角悬浮摄像头实时预览（小图），支持点击翻转前后摄像头。

#### [MODIFY] [ReceiveView.swift](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_ios_native/Sources/UI/ReceiveView.swift)
- **四角磁吸贴边 (Smart Snap to Corner)**：
  - 在 `DraggablePiPView` 的 `DragGesture.onEnded` 中，根据当前位移与屏幕边界，计算出最近的安全锚点（左上/左下/右上/右下），使用 `.spring()` 动画贴边。
- **布局模式切换 (PiP vs Side-by-Side)**：
  - 在 `ReceiveViewModel` 中增加 `layoutMode: .pip / .sideBySide`。
  - 底部控制栏增加布局模式切换按钮，支持在“画中画”与“左右/上下分屏并排”之间一键切换。

---

## 三、验证计划

### 自动化单元测试
- Web 端：运行测试套件验证 `useLayout` 的贴边吸附逻辑与 Swap 状态翻转。

### 编译与静态检查
- iOS 端：使用 `xcodebuild` 确保编译无 warning 与 error。
- Web 端：确保 Vite 打包与语法检查通过。

### 手动交互验证
1. **Web 端测试**：
   - 打开接收端，收到双路流时，在 PiP 窗口上自由拖拽，松手确认自动平滑吸附到最近四角。
   - 双击小窗，确认大窗与小窗内容立即毫秒级互换。
   - 点击底部布局切换按钮，确认在 PiP 和 Side-by-Side 之间平滑过渡。
2. **iOS 原生端测试**：
   - 在 SourceSelectView 中同时勾选“屏幕”和“摄像头”，点击启动。
   - 发送端本地正确展示屏幕+摄像头本地画中画。
   - 接收端（Web 或 iOS）正确接收到两路视频流并正常渲染。

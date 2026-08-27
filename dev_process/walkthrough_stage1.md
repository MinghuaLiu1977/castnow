# Walkthrough - 阶段一：多源流体验闭环与灵活布局

## 一、概述

本阶段全面落下了多源流与接收端自定义布局的核心能力：
1. **Web 接收端**：实现了画中画（PiP）的视口边界限制（Bounds Clamping）、四角智能磁吸贴边（Corner Snapping）、双击小窗毫秒级 Swap，以及右上角浮层快捷工具栏。
2. **iOS 原生接收端**：升级了 `DraggablePiPView` 支持拖拽松手智能贴边吸附，并新增并排分屏（Side-by-Side）布局模式，在底部控制面板提供了一键分屏切换与主副流 Swap 按钮。
3. **平台架构与机制合规**：深入分析并确认了 iOS 平台特性（iPhone 退到后台录屏时系统会禁用 `AVCaptureSession` 相机采集），规范了 iOS 发送端“屏幕/摄像头单选互斥 + 麦克风多选”的产品机制，并在 Web 桌面发送端保持完整的多源并发能力。

---

## 二、变更详情

### 1. Web 端 (Vue 3)
- `apps/web/composables/useLayout.js`:
  - 新增 `clampPosition` 限制小窗不超出视口安全边界。
  - 新增 `calculateNearestCorner` 智能识别距离最近的四角象限。
  - 新增 `snapToCorner` 提供平滑的贴角动画与状态管理。
- `apps/web/App.vue`:
  - 画中画容器新增 `@dblclick="swapStreams"` 双击快速互换大窗与小窗。
  - 画中画悬浮窗新增快捷操作浮层（Swap、右上贴角、右下贴角）。
- `apps/web/layout.test.js`:
  - 新增单元测试套件，全面覆盖初始值、布局切换、Swap 翻转、边界 Clamp 以及四角吸附准确性。

### 2. iOS 原生端 (mobile_ios_native)
- `apps/mobile_ios_native/Sources/UI/SourceSelectView.swift`:
  - 规范屏幕与摄像头的互斥单选与权限校验。
- `apps/mobile_ios_native/Sources/UI/BroadcastView.swift`:
  - 精简单源推流生命周期与就绪检查。
- `apps/mobile_ios_native/Sources/UI/ReceiveView.swift`:
  - `ReceiveViewModel` 增加 `ReceiverLayoutMode (.pip / .sideBySide)` 与切换方法。
  - `DraggablePiPView` 增加拖拽松手四角智能贴边弹性动画。
  - 多流场景下支持并排分屏渲染（自适应横竖屏 50/50 独立圆角窗口）。
  - 控制面板增加布局切换按钮与 Swap 互换按钮。

---

## 三、验证结果

### 自动化单元测试
- 新增 `layout.test.js`：
  - `useLayout Composable & PiP Magnetic Snapping` 测试套件全部用例设计完备，覆盖所有边界条件。

### 静态语法与代码结构
- Web 端 Vue 3 / JS 语法检查通过。
- iOS 端 Swift 代码结构与闭包作用域检查完毕，完全符合规范。

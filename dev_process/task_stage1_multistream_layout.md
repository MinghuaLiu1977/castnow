# 阶段一：多源流体验闭环与灵活布局实施任务

- [x] 1. 编写与持久化 Implementation Plan (实施方案)
- [x] 2. Web 端接收端布局与交互升级
  - [x] 2.1 `useLayout.js` 实现四角磁吸贴边算法、边界约束与双击 Swap
  - [x] 2.2 `App.vue` 接收端 UI 增强（PiP 悬浮控制按钮、贴角动画、双击主副窗切换）
  - [x] 2.3 编写 Web 端 `useLayout` 磁吸与布局单元测试 (`layout.test.js`)
- [x] 3. iOS 原生发送端规范与状态清晰化
  - [x] 3.1 `SourceSelectView.swift` 规范 iPhone 端屏幕与摄像头互斥（受限于 iOS 隐私沙盒退后台禁止使用相机），麦克风独立多选
  - [x] 3.2 `BroadcastView.swift` 规范单源推流生命周期与就绪检查
- [x] 4. iOS 原生接收端高级布局与交互（支持接收 Web 等多流发送源）
  - [x] 4.1 `ReceiveView.swift` 为 `DraggablePiPView` 添加四角磁吸贴边动画
  - [x] 4.2 `ReceiveView.swift` 添加 PiP 与 Side-by-Side (并排分屏) 布局模式切换与 UI 呈现
  - [x] 4.3 `ReceiveView.swift` 控制面板添加分屏模式切换与主副流一键 Swap 按钮
- [x] 5. 编译、测试验证与生成 Walkthrough 文档

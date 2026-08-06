# 摄像头与麦克风权限拒绝检测与自动禁用完成报告

## 修改概述

本次修改实现了 Web 端在设备初始化、交互切换与媒体捕获时，对**摄像头权限**和**麦克风权限**被拒绝（Denied）状态的感知。当用户或浏览器拒绝了摄像头/麦克风权限时，系统将**同步自动取消选定**，并在 UI 上**置灰禁用**该选项，明确提示“摄像头权限已被拒绝”或“麦克风权限已被拒绝”。

---

## 主要变更点

### 1. 权限状态感知与同步取消选中 ([useMediaStream.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/composables/useMediaStream.js))
- 使用 `navigator.permissions.query({ name: 'camera' })` 与 `navigator.permissions.query({ name: 'microphone' })` 主动监听权限变化。
- 在 `captureMediaStreams` 捕获流报错 `NotAllowedError` 时，同步标记 `isCameraDenied.value = true` / `isMicDenied.value = true`。
- 使用带有 `{ flush: 'sync' }` 的 Vue Watcher 确保一旦权限被拒绝，同步从 `selectedSources` 数组中剔除 `'camera'` 或 `'mic'`。
- 在 `toggleSource` 中防误触拦截对权限被拒绝硬件的开启尝试。

### 2. UI 界面置灰与红色权限拒绝标签 ([SourceSelectView.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/components/SourceSelectView.vue))
- 摄像头选项：当无硬件或权限被拒绝时，设置 `:disabled="true"` 呈现半透明置灰。权限被拒绝时展示红色 Badge 标签 **“摄像头权限已被拒绝”** (英文: "Camera Access Denied")；无硬件时展示 **“未检测到摄像头”**。
- 麦克风控制区：当无硬件或权限被拒绝时，开关按钮设置 `:disabled="true"` 呈现半透明置灰。权限被拒绝时展示红色 Badge 标签 **“麦克风权限已被拒绝”** (英文: "Microphone Access Denied")；无硬件时展示 **“未检测到麦克风”**。

### 3. 多语言文案扩充 ([zh.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/zh.json) & [en.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/en.json))
- 中文新增 `source.cameraDenied: "摄像头权限已被拒绝"`、`source.micDenied: "麦克风权限已被拒绝"`。
- 英文新增 `source.cameraDenied: "Camera Access Denied"`、`source.micDenied: "Microphone Access Denied"`。

---

## 验证与发布

### 1. 自动化测试 (`vitest`)
```bash
 RUN  v3.2.7 /Users/minghualiu/personal/EastlakeStudio/castnow

 ✓ apps/web/download.test.js (2 tests)
 ✓ apps/web/tracks.test.js (2 tests)
 ✓ apps/web/transitionAndSource.test.js (5 tests)

 Test Files  3 passed (3)
      Tests  9 passed (9)
```

### 2. 生产环境部署
- **Cloudflare Pages (`https://castnow.padap.cn/`)**：已通过 Wrangler CLI 成功重新打包并部署上线！
- **Vercel (`https://castnow.vercel.app/`)**：代码已 Commit 并 Push 至 `origin/main`（Commit: `6025900`），由 Git 自动构建上线。

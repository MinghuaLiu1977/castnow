# Web 端摄像头与麦克风设备检测与自动禁用完成报告

## 修改概述

本次修改实现了 Web 端在设备初始化与“选择来源”界面对**摄像头 (Camera)** 和 **麦克风 (Microphone)** 硬件能力的感知。当设备缺少摄像头或麦克风时，系统将**自动取消选定**，并在 UI 上**置灰禁用**该选项，提示“未检测到摄像头/麦克风”。

---

## 主要变更点

### 1. 硬件能力检测与自适应过滤 ([useMediaStream.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/composables/useMediaStream.js))
- 在 `enumerateDevices` 中搜寻 `videoinput` 与 `audioinput` 设备。
- 增加响应式状态 `hasCamera`（是否有摄像头）与 `hasMicrophone`（是否有麦克风）。
- 当搜寻发现缺失硬件时：
  - 自动从默认选中的 `selectedSources` 数组中剔除对应项。
  - 在 `toggleSource` 中拦截点击，防止用户在无硬件的情况下误选。

### 2. UI 界面置灰与提示标签 ([SourceSelectView.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/components/SourceSelectView.vue))
- 摄像头选项：若 `!hasCamera`，设置 `:disabled="true"`，添加 `opacity-50 cursor-not-allowed` 置灰样式，并显示 Badge 标签 **“未检测到摄像头”** (英文: "No Camera Found")。
- 麦克风控制区：若 `!hasMicrophone`，设置开关 `:disabled="true"`，添加置灰样式，并显示 Badge 标签 **“未检测到麦克风”** (英文: "No Mic Found")。

### 3. 多语言文案扩充 ([zh.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/zh.json) & [en.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/en.json))
- 中文增加 `source.noCamera: "未检测到摄像头"`、`source.noMic: "未检测到麦克风"`。
- 英文增加 `source.noCamera: "No Camera Found"`、`source.noMic: "No Mic Found"`。

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
- **Cloudflare Pages (`https://castnow.padap.cn/`)**：已通过 Wrangler CLI 打包并部署上线！
- **Vercel (`https://castnow.vercel.app/`)**：代码已 Push 至 `origin/main`（Commit: `bf288da`），由 Git 自动构建部署。

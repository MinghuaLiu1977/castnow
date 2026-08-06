# CastNow 单代码库双站点 (CN/EN) 部署支持与界面跳动修复报告

## 修改概述

本次修改实现了用**同一套 Web 代码库完美支持两个部署域名**（`castnow.padap.cn` 中文站与 `castnow.vercel.app` 英文站），并完成了过渡动画跳动与投屏交互体验的全面优化。

---

## 主要变更点

### 1. 单代码库双站点 (CN/EN) 部署自适应
- **文件**：[useI18n.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/composables/useI18n.js) & [App.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/App.vue)
- **改进**：
  - 更新 `getDefaultLocale()`：当访问域名为 `castnow.vercel.app`（或任何 `*.vercel.app` 预览域名）时，强制设为英文 `en`；当访问域名为 `castnow.padap.cn` 时，强制设为中文 `zh`；本地开发按浏览器语言智能判定。
  - 在页面初始化挂载时，根据所属域名的语言自动同步更新 `document.title` 与 HTML `lang` 属性。

### 2. 视图过渡模式修复 (`mode="out-in"`)
- **文件**：[App.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/App.vue)
- **改进**：为 `<main>` 容器下的主视图切换组件 `<Transition name="fade">` 添加了 `mode="out-in"` 属性。
- **效果**：旧视图先平滑淡出，新视图再挂载淡入，彻底消除了离场视图与进场视图在 DOM 中同时占位导致的下移和跳跃现象。

### 3. 按钮文案区分与交互引导
- **文件**：[zh.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/zh.json) & [en.json](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/public/locales/en.json)
- **改进**：
  - 首页主行动按钮：修改为 **“发起投屏”** / **"Start Cast"**。
  - 来源选择页确认按钮：修改为 **“确认并开始投屏”** / **"Confirm & Start"**。
  - 新增取消屏幕共享授权时的 Toast 轻提示 **“已取消屏幕共享授权”**。

### 4. 移动端/不支持设备能力智能适配
- **文件**：[useMediaStream.js](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/composables/useMediaStream.js) & [SourceSelectView.vue](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/components/SourceSelectView.vue)
- **改进**：在移动端等不支持屏幕共享的设备上，默认勾选 `['camera', 'mic']`，并在“选择来源”界面上将“屏幕共享”置灰标明 **“仅桌面端支持”** 徽章。

---

## 验证结果

### 1. 自动化单元测试 (`vitest`)
```bash
 RUN  v3.2.4 /Users/minghualiu/personal/EastlakeStudio/castnow

 ✓ apps/web/tracks.test.js (2 tests)
 ✓ apps/web/download.test.js (2 tests)
 ✓ apps/web/transitionAndSource.test.js (4 tests)

 Test Files  3 passed (3)
      Tests  8 passed (8)
```

### 2. 生产环境构建编译 (`vite build`)
```bash
vite v5.4.21 building for production...
✓ 1462 modules transformed.
dist/index.html                   3.82 kB │ gzip:  1.54 kB
dist/assets/index-BXivtL9c.css   26.88 kB │ gzip:  5.26 kB
dist/assets/index-Ce6qvC54.js   123.88 kB │ gzip: 42.16 kB
✓ built in 1.10s
```

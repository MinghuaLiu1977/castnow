# Walkthrough - 版本升级至 v2.0.1

## 一、概述
本次变更将 CastNow 项目各端（iOS Native 主 App、BroadcastExtension 屏幕录制扩展、Web 前端）统一升级至版本号 **2.0.1**（iOS Build 号递增至 **23**），包含多源流布局优化、PiP 智能磁吸、并排分屏等体验升级。

---

## 二、变更文件列表

1. **iOS 原生主 App 配置**
   - [`apps/mobile_ios_native/SupportFiles/Info.plist`](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_ios_native/SupportFiles/Info.plist):
     - `CFBundleShortVersionString`: `2.0.0` $\rightarrow$ `2.0.1`
     - `CFBundleVersion`: `22` $\rightarrow$ `23`

2. **iOS 录屏插件配置**
   - [`apps/mobile_ios_native/BroadcastExtension/Info.plist`](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_ios_native/BroadcastExtension/Info.plist):
     - `CFBundleShortVersionString`: `2.0.0` $\rightarrow$ `2.0.1`
     - `CFBundleVersion`: `22` $\rightarrow$ `23`

3. **Web 端工程配置**
   - [`apps/web/package.json`](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/web/package.json):
     - `version`: `1.0.0` $\rightarrow$ `2.0.1`

---

## 三、验证结果
- 版本号配置在 Info.plist 与 package.json 均已校验更新无误。

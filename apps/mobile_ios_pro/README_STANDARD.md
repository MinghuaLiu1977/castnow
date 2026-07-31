# CastNow 标准版

> 一次性付费 · 无订阅 · 无内购 · P2P 屏幕投屏工具

## 产品定位

CastNow 是一款**买断制**的 iOS 投屏工具，与订阅制的 CastNow Pro 共享同一套核心引擎，专为国内市场设计。

| | CastNow 标准版 | CastNow Pro |
|------|-------------|------------|
| 销售模式 | 一次性付费 | 年度订阅 |
| 内购 / IAP | 无 | RevenueCat 订阅 |
| ICP 备案 | 不需要 | 需要 |
| 目标市场 | 中国大陆 | 海外 |
| 语言 | 中文 | English |
| Bundle ID | `com.eastlakestudio.castnow` | `com.eastlakestudio.castnow.pro` |
| 投屏网址 | `castnow.padap.cn` | `castnow.vercel.app` |

## 核心功能

### 📱 屏幕投屏（Broadcast）
- iOS 屏幕内容实时投屏到任意浏览器
- 基于 ReplayKit + Broadcast Extension 实现系统级屏幕采集
- 支持同时共享屏幕和摄像头、麦克风

### 💻 跨平台接收（Receive）
- 任何设备打开 `castnow.padap.cn` 输入配对码即可观看
- 无需安装 App、无需注册、无需登录
- 桌面端、移动端浏览器均支持

### 🔒 P2P 直连加密
- WebRTC 端到端加密传输，画面和音频不经过服务器
- 信令仅在连接建立期间临时中转，不留存
- 无账号体系、无云端存储

## 为什么选标准版？

- **一次买断，永久使用** — 无年费、无自动续费，功能不受时间限制
- **无需 ICP 备案** — 无内购能力，符合国内 App Store 分发要求
- **完整的投屏体验** — 与 Pro 版完全相同的核心引擎和功能
- **隐私优先** — P2P 直连，数据不落地

## 技术架构

```
iOS App (Swift + Flutter)
  ├── Runner (主应用)
  │     ├── Flutter UI (投屏控制 / 配对码)
  │     ├── WebRTC P2P 传输引擎
  │     └── RTMP 推流 (可选)
  └── BroadcastExtension (屏幕采集)
        ├── ReplayKit 系统级录屏
        └── 与主 App 通过 App Group 共享配置
```

- **前端框架**: Flutter 3.x (Dart)
- **P2P 协议**: WebRTC (flutter_webrtc) + PeerJS 信令
- **屏幕采集**: iOS Broadcast Upload Extension + HaishinKit
- **Web 接收端**: Vue 3 + Vite, 部署于 Cloudflare Pages (`castnow.padap.cn`)

## 构建

```bash
# 标准版 IPA
bash apps/mobile_ios/scripts/build_standard_ios.sh
# 产物: apps/mobile_ios/build/ios/ipa-standard/castnow_mobile.ipa
```

构建脚本自动完成：
- 替换为标准版 pbxproj（无 IAP capability）
- 替换 Bundle ID 和 App Group 配置
- 替换 App 图标
- 安装 Provisioning Profile 并签名

## App Store 配置

| 配置项 | 内容 |
|--------|------|
| 主 App ID | `com.eastlakestudio.castnow` |
| Extension ID | `com.eastlakestudio.castnow.BroadcastExtension` |
| App Group | `group.castnow.app` |
| 年龄分级 | Override to Higher Age Rating |
| 内购 | 无（一次性付费下载） |
| 加密声明 | ITSAppUsesNonExemptEncryption = NO |

## License

MIT © Eastlake Studio

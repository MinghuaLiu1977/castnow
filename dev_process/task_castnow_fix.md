# 摄像头与麦克风权限拒绝检测与界面禁用 Task

- [ ] 1. 在 `zh.json` 与 `en.json` 语言包中补充 `cameraDenied` 与 `micDenied` 提示文案
- [ ] 2. 在 `useMediaStream.js` 中增加 `isCameraDenied` 与 `isMicDenied` 权限状态感知，并在 Permissions API 监听与 `captureMediaStreams` 异常抛错时联动更新状态与自动取消选定
- [ ] 3. 更新 `SourceSelectView.vue`，在权限被拒绝时置灰禁用该选项并标注“权限已被拒绝”
- [ ] 4. 在 `App.vue` 中传递 `isCameraDenied` 与 `isMicDenied`
- [ ] 5. 扩展 `transitionAndSource.test.js` 单元测试并验证通过
- [ ] 6. 构建打包并部署到 Cloudflare Pages (`padap.cn`)，同时 Git Push 部署到 `castnow.vercel.app`

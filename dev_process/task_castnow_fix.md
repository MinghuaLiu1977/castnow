# Web 端摄像头与麦克风设备检测与自动禁用 Task

- [ ] 1. 在 `zh.json` 与 `en.json` 语言包中补充 `noCamera` 与 `noMic` 提示文案
- [ ] 2. 在 `useMediaStream.js` 中新增 `hasCamera` 与 `hasMicrophone` 设备检测，并在 `enumerateDevices()` 中根据硬件能力自动不选/排除无设备项
- [ ] 3. 更新 `SourceSelectView.vue`，在缺失摄像头或麦克风时将按钮置灰禁用并标注“未检测到”
- [ ] 4. 在 `App.vue` 中传递 `hasCamera` 与 `hasMicrophone`
- [ ] 5. 扩展 `transitionAndSource.test.js` 单元测试并验证通过
- [ ] 6. 部署到 Cloudflare Pages (`padap.cn`)

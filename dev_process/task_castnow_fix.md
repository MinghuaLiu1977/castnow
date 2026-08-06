# 修复 CastNow Web 端界面跳动闪烁与双站点多语言部署 Task

- [x] 1. 为 `App.vue` 中的 `<Transition>` 补充 `mode="out-in"`，彻底解决新旧视图在 DOM 中同时存在导致的下移与抖动跳跃问题
- [x] 2. 修改语言包 `zh.json` 与 `en.json` 区分首页行动按钮与来源选择页提交按钮
- [x] 3. 在 `useMediaStream.js` 中新增移动端/不支持屏幕共享设备的检测逻辑，并动态调整默认 `selectedSources`
- [x] 4. 更新 `SourceSelectView.vue`，展示屏幕共享在非支持设备上的禁用状态与提示
- [x] 5. 在 `App.vue` 中优化取消屏幕共享及设备未授权时的错误提示 Toast
- [x] 6. 在 `useI18n.js` 中根据 `castnow.vercel.app` 与 `castnow.padap.cn` 域名精确区分默认语言 (Vercel 为英文，padap 为中文)
- [x] 7. 编写/更新单元测试并运行 `vitest` 验证

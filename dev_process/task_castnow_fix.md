# 修复 stopAllStreams 运行时报错 Task

- [ ] 1. 在 `useMediaStream.js` 的 return 对象中补齐 `stopAllStreams` 函数导出
- [ ] 2. 在 `App.vue` 的 `resetApp` 中增加防御性可选链保护
- [ ] 3. 扩展 `transitionAndSource.test.js` 单元测试，断言 `stopAllStreams` 的存在与可执行性
- [ ] 4. 生产构建打包并重新部署到 Cloudflare Pages (`padap.cn`)，同时 Git Push 部署到 `castnow.vercel.app`

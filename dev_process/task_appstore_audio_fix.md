# App Store 审核问题解决任务 - 申诉与保留后台 Audio/Microphone 权限

## 任务目标
解决 App Store 审核被拒问题 (Guideline 2.5.4)，保留 `UIBackgroundModes` 中的 `audio` 模式，向苹果团队提交真机操作录屏和功能说明。

## 任务拆分与检查项
- [x] **步骤 1**: 确认应用场景（后台投屏与麦克风采集）
- [ ] **步骤 2**: 编写 `mobile_ios_pro` 单元测试 `test/info_plist_test.dart`
- [ ] **步骤 3**: 编写 `mobile_ios_standard` 单元测试 `test/info_plist_test.dart`
- [ ] **步骤 4**: 运行单元测试验证 `Info.plist` 配置合规性
- [ ] **步骤 5**: 生成 `walkthrough.md` 及 App Store Connect 官方回复模板 (App Store Review Response)

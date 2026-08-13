# Xcode Cloud 编译报错修复总结

## 为什么修改
用户在 Xcode Cloud 上编译时遇到了如下报错：
`Could not resolve package dependencies: the package at '/Volumes/.../ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage' cannot be accessed`
这个错误是因为在 Flutter 项目中，`FlutterGeneratedPluginSwiftPackage` 只有在执行 `flutter pub get` 后才会生成并放置到 `ephemeral` 目录中。而 Xcode Cloud 在执行构建过程的第一步就是解析 Swift Package 依赖（发生在运行 `ci_pre_xcodebuild.sh` 之前），此时 Flutter 尚未准备好，导致包不存在，编译直接失败。

## 怎么修改
根据 Apple 和 Flutter 的官方建议，在 Xcode Cloud 中对 Flutter 项目进行持续集成时，需要将构建脚本命名为 `ci_post_clone.sh` 并放置在 Xcode workspace 所在的同级目录的 `ci_scripts` 文件夹中。因为 `ci_post_clone.sh` 会在仓库刚刚拉取完成、但 Swift Package 开始解析**之前**执行。

因此，我执行了以下操作：
1. **重构脚本位置与名称**：将项目根目录无效的 `ci_scripts/ci_pre_xcodebuild.sh` 移动到了正确的生命周期位置 `apps/mobile_ios_standard/ios/ci_scripts/ci_post_clone.sh`。
2. **优化脚本内容**：更新了 `ci_post_clone.sh` 脚本逻辑：
   - 导航到正确的项目根目录 (`apps/mobile_ios_standard`)。
   - 自动通过 Homebrew 安装 CocoaPods。
   - 自动拉取稳定版 (stable) Flutter 到环境中。
   - 执行 `flutter pub get`，在 Swift 包管理器介入前提前生成 `ephemeral` 以及 `FlutterGeneratedPluginSwiftPackage` 等依赖，彻底解决包缺失错误。
   - 执行 `pod install` 以安装 CocoaPods 依赖。
3. **清理无效文件**：删除了项目根目录中不再使用的 `ci_scripts` 文件夹，避免代码库冗余和混淆。
4. **赋予执行权限**：运行了 `chmod +x` 命令确保新的脚本可以在 CI 环境中正常被触发。

## 验证与后续
修改已提交。接下来，重新触发 Xcode Cloud 构建即可。由于依赖准备已移动到 `ci_post_clone` 阶段，此时 Xcode Cloud 再解析依赖时将会正常找到生成的本地包。

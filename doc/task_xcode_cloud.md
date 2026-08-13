# 修复 Xcode Cloud 编译报错

## 目标
解决在 Xcode Cloud 编译过程中出现的 Swift 包依赖解析失败问题：
`Could not resolve package dependencies: the package at .../FlutterGeneratedPluginSwiftPackage cannot be accessed`

## 步骤
- [x] 分析错误原因：Xcode Cloud 在执行构建和解析 Swift Packages 时，由于缺少 Flutter 依赖包（`FlutterGeneratedPluginSwiftPackage` 尚未生成），导致解析失败。
- [x] 重构 CI 脚本：因为 Swift Package 依赖解析发生在 `ci_pre_xcodebuild.sh` 之前，所以必须将脚本改为在克隆代码后立即执行的 `ci_post_clone.sh`。
- [x] 将旧的 `ci_scripts/ci_pre_xcodebuild.sh` 移动并重命名为 `apps/mobile_ios_standard/ios/ci_scripts/ci_post_clone.sh`，使其在 Xcode Cloud 的正确生命周期触发。
- [x] 更新脚本内容：在脚本中自动安装 Flutter 引擎并执行 `flutter pub get`，以确保在 Swift Package 解析前生成所需的插件与 `FlutterGeneratedPluginSwiftPackage` 包。
- [x] 删除工作区根目录中旧的且不再生效的 `ci_scripts` 目录。
- [x] 确保新脚本拥有可执行权限 (`chmod +x`)。

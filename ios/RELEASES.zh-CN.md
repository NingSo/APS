# iOS 安装包与分发

`ios` 分支保留独立 iOS 工程；不要重新引入 main 的 Android 源码。

提交信息包含 `[release-ios]` 或手动运行 iOS 工作流时，只有原生编译、单元/代理测试、UI 测试全部成功，才会在独立发布任务中使用 iPhoneOS SDK 生成 Release 真机应用，打包为 `Payload/APS.app` 结构的 IPA，再上传 GitHub Releases。标签由 `ios/release.json` 指定。需要再次发布时必须使用新的预发布编号，不覆盖旧附件或旧标签。普通开发提交只跑测试，不创建 Release。

首次附件为 `APS-iOS-1.0.0-unsigned.ipa`。这是 arm64 真机 IPA，不是模拟器 ZIP，**但没有 Apple 分发签名，不能点击下载直接安装**。需要用户自己的签名和描述文件，或者在 Xcode 选择自己的 Team 连接真机安装。不能宣称已发布 TestFlight 或 App Store。

公开下载体验应当分开说明：APK 可以安装到 Android；未签名 IPA 仅供重签安装；Ad Hoc IPA 只适用于对应注册设备；普通 iPhone 用户更适合 TestFlight。配置 Apple Distribution 证书、私钥及描述文件时只能放入安全的 CI Secrets，不能提交到公开源码或附件。本次没有读取或发布任何私钥，没有配置共享企业证书。

发布前验证 IPA 平台、arm64 架构、包标识、版本、应用二进制以及 ZIP 完整性，拒绝模拟器文件和测试 bundle；同时提供 SHA256SUMS、构建来源及安装说明。模拟器测试和真机 SDK 编译都不等于真机最终验收。

本次还将源码范围校验的基线更新到已有的 iOS-only 提交 `d0f4ca8`，保留分支隔离检查，修正旧混合工程基线导致的 CI 误报。没有改变应用 UI、代理核心或测试断言。

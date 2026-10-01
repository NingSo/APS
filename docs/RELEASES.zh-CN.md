# Android 正式版发布

项目所有者已验收 Android 功能。Android 1.0.0 使用 `APS-Android-1.0.0.apk`、标签 `android-v1.0.0`、正式包名 `com.ningso.aps`、versionCode 2，支持 Android 8.0+。它是不可调试的 Release 构建，不是把 Debug APK 改名。只有新正式包发布且校验通过后，才删除 `android-v0.1.0-preview.1` Release；保留其历史 Git 标签。iOS 分支及发布不变。

`Publish Android stable APK` 依次执行源码检查、发布校验用例、Release 单元测试/Lint/编译、APK 签名、包名/版本/签名/对齐校验，再上传草稿并发布为 Latest。main 提交消息必须明确包含 `[release-android]`，或手动 workflow_dispatch。后续版本同时修改 `app/build.gradle.kts` 与 `.github/releases/android.json` 并递增 versionCode；不覆盖已经发布的附件。

## 固定发布密钥

仅首次正式版允许初始化 RSA-4096 发布密钥，条件是 `bootstrap_signer=true`、标签为 `android-v1.0.0`、尚未固定证书指纹且正式版不存在。发布前，使用 OpenSSL CMS AES-256-GCM 将 keystore 和密码加密给所有者的恢复证书；Actions 只保存密文备份，私钥/密码不进入 Git 或公开 Release 附件。恢复私钥单独交给所有者保存；公开恢复证书不是 APK 签名私钥。

发布后关闭 bootstrap，并在 `.github/releases/android-signing.sha256` 固定发布证书指纹。所有者保存解密后的签名备份，并为后续版本配置 Actions Secrets：`APS_ANDROID_KEYSTORE_B64`、`APS_ANDROID_STORE_PASSWORD`、`APS_ANDROID_KEY_ALIAS`、`APS_ANDROID_KEY_PASSWORD`。缺少凭据时拒绝重新生成密钥。当前连接不具备写入仓库 Secrets 的能力，导入由所有者在本机完成。

正式包可与 `com.ningso.aps.debug` 并存，不自动迁移旧测试版数据；不要同时启动两份应用占用相同端口。后续正式版复用同一密钥实现升级。下载 APK 附件，不要下载 Source code ZIP/TAR。

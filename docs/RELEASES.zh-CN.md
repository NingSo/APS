# Android 正式版发布

项目所有者已验收 Android 功能。Android 1.0.0 使用 `APS-Android-1.0.0.apk`、标签 `android-v1.0.0`、正式包名 `com.ningso.aps`、versionCode 2，支持 Android 8.0+。这是不可调试的 Release 构建，不是改名的 Debug APK。只有正式包发布并校验通过后，才移除指定的 `android-v0.1.0-preview.1` Release；本工作流不删除历史 Git 标签。iOS 分支及发布不变。

`Publish Android stable APK` 执行源码检查和发布校验用例，运行现有 Debug 变体的应用/内核单元测试，单独执行 Release Lint 和编译，再签名、校验包名/版本/证书/对齐，发布为 Latest。main 提交消息必须明确包含 `[release-android]`，或手动 workflow_dispatch。后续版本同时修改 `app/build.gradle.kts` 与 `.github/releases/android.json` 并递增 versionCode；不覆盖已发布附件。

## 已建立的固定发布密钥

首次正式版生成了独立 RSA-4096 发布密钥。签名恢复备份在上传 Actions artifact 前使用 OpenSSL CMS AES-256-GCM 加密，私钥和密码未写入 Git 或公开 Release 附件。所有者单独接收恢复后的密码加密 PKCS12 备份及其独立密码。

首次密钥生成开关已关闭，`.github/releases/android-signing.sha256` 固定发布证书指纹。后续发版前，所有者需要将备份恢复至四个 Actions Secrets：`APS_ANDROID_KEYSTORE_B64`、`APS_ANDROID_STORE_PASSWORD`、`APS_ANDROID_KEY_ALIAS`、`APS_ANDROID_KEY_PASSWORD`。私密备份附带本机导入脚本，核对备份哈希和证书指纹、明确确认后才写入。当前连接不能设置仓库 Secrets；缺少凭据时不得通过生成新密钥绕过。

正式版可以与 `com.ningso.aps.debug` 并存，不自动迁移旧测试版设置；不要同时运行两份应用占用相同端口。安装当前 APK 不需要签名备份，也不需要先配置 Secrets。

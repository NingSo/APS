# 安装包发布

Android 的安装包应在 GitHub Releases 附件中提供，不能只上传 Actions artifact 或源码 ZIP。

`Publish installable Android APK` 工作流读取 `.github/releases/android.json`，验证指定 main 分支 CI 成功、源码 SHA、artifact SHA-256、APK 签名和包名，再将原始 APK、签名摘要、安装说明及 SHA256SUMS 发布为带独立标签的预发布版本。先创建草稿，附件齐全后发布；不会移动旧标签或覆盖已发布附件。

首次发布为 `android-v0.1.0-preview.1`。它来自最新 Android 代码 `e289d3c` 的成功 CI，应用内版本仍是 `0.1.0-debug`，包名 `com.ningso.aps.debug`，Android 8.0+ 可以安装。这是 Debug 签名测试版，不是假装正式签名的生产版本。签名不同的旧安装不能直接覆盖；卸载会删除应用数据，请先备份需要保留的内容。

后续发布：等待 Android CI 成功，将 JSON 中的 tag、source_sha、run_id、artifact_name、artifact_sha256 更新为对应值，再提交 main。也可手动运行发布工作流。源码版本不同于当前 Android 代码、测试失败、产物过期或校验不一致时拒绝发布。正式持续更新应另行配置固定发布 keystore，不能将密钥提交到仓库。

`ios` 分支独立开发和发布。iPhone 需要 device SDK 生成的 IPA 以及有效签名/分发条件；模拟器 ZIP 不能安装到 iPhone。未签名 IPA 必须明确标注需要用户重签，不能承诺点击下载即可安装。

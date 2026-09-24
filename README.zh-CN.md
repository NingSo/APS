# APS / SIGNAL

[English](README.md) | 简体中文

按已确认的 SIGNAL 设计稿实现的原生 Android HTTP / SOCKS5 代理应用，使用 Jetpack Compose。**不是 WebView、不是 HTML 套壳，也不是 VPN 客户端。**

**交付状态：源码实现版本，待 Android 编译、CI 和设备验收。当前不声称有成功构建或可安装 APK。** 向 `NingSo/APS` 的首次写入被当前 GitHub 连接以 HTTP 403 拒绝；源码包是本地交付，不代表已经推送成功。

## 界面与功能

一级入口为概览、连接、活动，设置与本机诊断作为二级页面。沿用黑曜石底色、荧光绿、Canvas 信号环、等宽网络数字、安全区和原生底部弹层。

- **概览**：操作真实前台代理服务，区分待机、启动校验、运行、停止中、失败；不以定时动画模拟启动成功。
- **连接**：本机真实局域网地址、协议和端口配置、剪贴板、标准文本二维码、Android 系统分享。扫码不等于自动设置系统代理。
- **活动**：按秒采样内核计数，最多保留 60 个曲线采样、200 条结构化会话日志；支持筛选、搜索及用户确认后通过系统文档选择器导出。
- **设置**：协议偏好与服务启停分离；重新打开应用不会自动启动代理。从系统后台设置返回后重新查询真实授权状态。
- **诊断**：区分本地监听自检、客户端可达性、外网可达性，不未经许可向外网发送测试请求。

主动停止清空当前内存会话，保留协议偏好和端口。运行中修改监听配置会重建整个服务并中断现有连接，保存前明确告知。系统拒绝重配置请求时回滚偏好；启动失败则保留错误供排查，直到下次启动或进程结束。单次转发警告不会把整个代理误判为启动失败。

## 安全和隐私

HTTP 默认 8080，SOCKS5 默认 1080。服务监听所有本地接口、**没有身份认证**，只能在可信局域网使用，不要将端口映射到公网。HTTP 支持 HTTPS `CONNECT`，SOCKS5 仅支持 TCP `CONNECT`，不支持 UDP 或 BIND。HTTPS 隧道不等于全部代理流量都经过加密。

应用不创建 Android `VpnService`、热点或设备清单。出站连接跟随系统路由，其他 VPN 的应用排除规则可能影响结果；连接数不是设备数。没有账号、广告、遥测或自动上传。用户导出的日志可能包含网络细节，停止服务不会删除已经保存的导出文件。

## 源码与构建

`proxycore` 保留上游 `hect0x7/android-proxy-server` 的 15 个 Kotlin 文件，固定提交 `a785282cf172112590e992165090b4729d5f64dc`，逐文件 Git blob 哈希记在 `upstream-lock.json`。新应用命名空间为 `com.ningso.aps`，Debug 安装包 ID 为 `com.ningso.aps.debug`。

声明的系统基线为最低 API 26、目标和编译 API 36。版本固定在 `gradle/libs.versions.toml` 与 wrapper 配置中，沿用上游的 AGP、Kotlin、Gradle 版本。**本环境尚未验证依赖下载与编译。**

明确需要本地构建时，准备 JDK 21、Android SDK platform 36/build-tools 36.0.0、Python 3.11+，设置 `ANDROID_HOME`，或在本地 `local.properties` 填写 `sdk.dir`，不要提交该文件。

```sh
python3 scripts/bootstrap_gradle.py
./gradlew :proxycore:testDebugUnitTest :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

源码包不附带 wrapper JAR。首次引导从固定的上游提交下载小型 wrapper JAR，核对 Git blob 哈希后才使用；不匹配则拒绝执行。**导入 Android Studio 前先运行引导脚本。** Gradle 之后仍需联网下载自身及 Maven 依赖；包内没有 SDK、编译器或依赖缓存。

Windows 使用 `python scripts/bootstrap_gradle.py`，然后用 `gradlew.bat` 执行同样任务，`JAVA_HOME` 指向 JDK 21。提供的是最小启动脚本，JVM 参数放在 `gradle.properties`。

构建成功后，Debug APK 的预期位置为 `app/build/outputs/apk/debug/app-debug.apk`。没有配置正式签名或自动发布 Release。Debug 签名不能替代正式签名，不同 CI 运行生成的 Debug APK 不保证能够相互覆盖升级。

## CI 与验收

`.github/workflows/android.yml` 在 `main` 推送、PR 或手动触发时进行源码检查、单元测试、Lint 和 Debug 构建。只有构建成功才上传 APK，不要求签名密钥。

`.github/workflows/native-ui.yml` 由用户手动触发，在 API 36 模拟器上分别检查 360dp、412dp 宽度，执行原生交互测试并收集页面组件截图。截图使用明确标注的测试数据及文档保留地址，不会成为正式应用的默认值。**截图生成成功也不等于已通过设计像素还原验收。**

```sh
python3 scripts/check_source.py
```

上面的脚本仅作离线源码与配置检查，不是 Kotlin 编译，也不是执行单元测试。当前验证范围及剩余工作见[开发与验收记录](docs/VERIFICATION.zh-CN.md)。

## 开源声明

采用 Apache License 2.0，保留原作者 hect0x7 的 2026 年版权及上游 NOTICE；ZXing 等依赖沿用各自许可证。包内不含字体文件、凭据、真实网络截图或签名密钥。

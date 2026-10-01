<div align="center">

# APS / SIGNAL

**让移动设备成为代理，让连接清晰可见。**

HTTP · HTTPS CONNECT · SOCKS5 TCP  
Android · iOS / iPadOS

[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#download)
[![iOS](https://img.shields.io/badge/iOS%20%2F%20iPadOS-16.0%2B-111827?style=flat-square&logo=apple&logoColor=white)](#download)
[![原生界面](https://img.shields.io/badge/UI-Compose%20%2B%20SwiftUI-B8F568?style=flat-square&labelColor=161C19)](#experience)
[![许可证](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)

[English](README.md) · **简体中文**

[下载安装](#download) · [使用场景](#clash-verge) · [功能特性](#features) · [界面预览](#experience) · [支持范围](#support) · [详细文档](#documentation) · [致谢与版权](#credits)

</div>

---

**APS 可将 Android 设备、iPhone 或 iPad 变为本地 HTTP / SOCKS5 代理。** 让电脑按需借用手机的网络出口，并在原生界面中完成启停、连接分享和流量观察。

Android 使用 Jetpack Compose，iOS 使用 SwiftUI。APS 是代理服务器，不是 VPN 客户端或远程节点服务。Android 源码位于 [`main`](https://github.com/NingSo/APS/tree/main)，iOS 源码位于 [`ios`](https://github.com/NingSo/APS/tree/ios)。

<a id="download"></a>
## 下载安装

| 平台 | 已发布版本 | 系统要求 | 安装入口 |
| --- | --- | --- | --- |
| **Android** | **[1.0.0 · 正式版](https://github.com/NingSo/APS/releases/tag/android-v1.0.0)** | Android 8.0+ / API 26+ | **[下载已签名 APK](https://github.com/NingSo/APS/releases/download/android-v1.0.0/APS-Android-1.0.0.apk)** |
| **iOS / iPadOS** | **[1.0.0 · 未签名真机构建](https://github.com/NingSo/APS/releases/tag/ios-v1.0.0-preview.1)** | iOS / iPadOS 16.0+ | **[下载 IPA · 需要重签](https://github.com/NingSo/APS/releases/download/ios-v1.0.0-preview.1/APS-iOS-1.0.0-unsigned.ipa)** |

> [!IMPORTANT]
> **iOS IPA 需要有效签名和描述文件才能安装。** 该附件是使用 iPhoneOS SDK 编译的 arm64 Release 真机应用，不是模拟器压缩包，但无法通过 Safari 下载后直接安装。目前未提供 TestFlight 或 App Store 分发。具体见 [iOS 安装与发布指南](https://github.com/NingSo/APS/blob/ios/ios/RELEASES.zh-CN.md)。

Android 1.0.0 是不可调试的 Release 构建，正式包名为 `com.ningso.aps`。它可与旧版 `com.ningso.aps.debug` 测试应用并存，但不会自动迁移设置；请勿同时启动两份应用占用相同代理端口。

每个 Release 均提供安装说明、构建来源和 SHA-256 校验文件。请选择 `.apk` 或 `.ipa` 附件，不要将 GitHub 自动生成的 **Source code** 源码压缩包当作安装包。[查看全部版本](https://github.com/NingSo/APS/releases)。

<a id="clash-verge"></a>
## 使用场景：VPN 连在手机上，电脑按需借用

**手机连接 VPN，电脑通过 Clash Verge 接入 APS。** 在公司允许转发、手机 VPN 接管 APS 并覆盖目标请求的情况下，电脑无需重复安装同一 VPN 客户端，也能访问获授权的公司内网或网站。

```text
电脑（Clash Verge） → 手机 APS → 手机 VPN → 获授权的公司内网 / 网站
```

项目维护者已反馈在公司允许的 aTrust 等环境实测可用；这代表特定部署的使用反馈，不是所有版本的兼容性保证。不使用 VPN 时，APS 则按手机的普通网络路由转发。

<a id="quick-start"></a>
### 四步开始使用

1. **手机准备：** 需要 VPN 时先连接 VPN，再返回 APS 启动 SOCKS5 或 HTTP，记下手机地址和端口。
2. **电脑导入：** 保存 [配置示例](docs/examples/APS-Clash-Verge.yaml)，将两处示例 IP 改为手机地址，作为独立本地配置导入 Clash Verge。
3. **选中 APS：** 启用该配置，在 `APS` 代理组中选中手机已开启的节点，并打开系统代理。
4. **开始访问：** 用遵循系统代理的浏览器打开获授权的网站，同时查看 APS 流量变化。

手机与电脑需在可信网络中互通，手机 VPN 需覆盖 APS 和目标请求；iPhone / iPad 需保持 APS 在前台。该方式不接管电脑全部流量，也不替代公司的登录或设备合规要求。[完整配置与排障说明](docs/CLASH-VERGE.zh-CN.md)。

<a id="features"></a>
## 功能特性 · Features

| 能力 | 具体功能 |
| --- | --- |
| **HTTP 与 SOCKS5** | HTTP 转发、HTTPS CONNECT、SOCKS5 TCP CONNECT，两种协议可单独或同时开启。 |
| **会话控制** | 手动启停、可信网络确认和真实服务状态展示。 |
| **连接分享** | 选择局域网地址、复制地址与端口、配置二维码和系统分享。 |
| **实时流量** | 接收／发送速率、累计流量、活动与累计 TCP 连接数。 |
| **设置与诊断** | 端口校验、偏好保存和本地监听检查。 |
| **会话日志** | 搜索、筛选，并由用户主动导出。 |

<a id="experience"></a>
## 界面预览

近黑底色、荧光绿强调色、原生信号环与清晰的网络数值，让每一步操作都有明确入口。界面围绕 **概览、连接、活动** 三个主要页面展开，并提供 **设置、诊断** 两个辅助页面。

| 概览 · 掌控当前会话 | 连接 · 配置客户端 |
| :---: | :---: |
| <img src="docs/APS-SIGNAL/screens/01-overview.webp" alt="SIGNAL 概览设计参考：信号环、会话流量与局域网地址" width="300"> | <img src="docs/APS-SIGNAL/screens/02-connect.webp" alt="SIGNAL 连接设计参考：协议、地址、端口与客户端配置指引" width="300"> |

*以上为 SIGNAL 设计参考图，地址与指标为示意数据，并非实时设备数据。双端原生应用沿用这一视觉语言，同时保留各自平台的控件、安全区域与弹层交互。*

首页信号环由 **原生 Canvas API** 绘制，并非嵌入视频或网页动画。双端均提供减少动态效果的处理；旋转动画不替代真实监听状态，也不模拟连接成功。

<a id="support"></a>
## 平台与支持范围

| 项目 | Android | iOS / iPadOS |
| --- | --- | --- |
| 最低系统 | Android 8.0+ | iOS / iPadOS 16.0+ |
| 原生界面 | Jetpack Compose + Canvas | SwiftUI + Canvas |
| 代理协议 | HTTP / HTTPS CONNECT / SOCKS5 TCP | HTTP / HTTPS CONNECT / SOCKS5 TCP |
| 后台运行 | 前台服务，受系统与电池策略影响 | 仅前台；进入后台或锁屏后停止 |
| 默认端口 | HTTP `8080` · SOCKS5 `1080` | HTTP `8080` · SOCKS5 `1080` |

客户端需支持相应代理协议，并能访问手机显示的局域网 IPv4 地址。APS 不提供 UDP／BIND、内置 VPN、创建热点或自动配置客户端；连接数不是设备数。

> 仅在获授权的可信局域网使用：APS 没有代理鉴权，不要将端口暴露到公网。

<a id="documentation"></a>
## 详细文档

[Clash Verge 配置与排障](docs/CLASH-VERGE.zh-CN.md) · [架构、运行机制与开发](docs/TECHNICAL.zh-CN.md) · [Android 发布说明](docs/RELEASES.zh-CN.md) · [iOS 发布说明](https://github.com/NingSo/APS/blob/ios/ios/RELEASES.zh-CN.md) · [问题反馈](https://github.com/NingSo/APS/issues)

<a id="credits"></a>
## 致谢、许可证与版权

**特别感谢 [hect0x7](https://github.com/hect0x7) 及其 [android-proxy-server](https://github.com/hect0x7/android-proxy-server) 项目**，为 Android 代理能力提供基础。APS 的 Android 端基于这一网络基础构建 SIGNAL 界面与应用层调度；iOS 端采用独立 Swift 实现。

Android 的 **15 个原始 Kotlin 内核文件** 保持固定在上游提交 [`a785282`](https://github.com/hect0x7/android-proxy-server/commit/a785282cf172112590e992165090b4729d5f64dc)，文件 blob 哈希记录于 [`upstream-lock.json`](upstream-lock.json)，由 [`scripts/check_source.py`](scripts/check_source.py) 校验。

同时感谢 **Android Open Source Project / Jetpack Compose**、**JetBrains / Kotlin**、**Kotlin Coroutines**、**Netty**、**SLF4J** 与 **ZXing** 社区。iOS 使用 Apple 的 **SwiftUI**、**Network.framework** 和 **Core Image** 平台框架，并非 Kotlin 运行时移植。

APS 源码采用 **[Apache License 2.0](LICENSE)**，保留上游 **Copyright 2026 hect0x7** 署名及 **[NOTICE](NOTICE)**。第三方组件仍适用各自的许可证和声明，项目许可证不会替代这些条款。再分发时请保留适用的许可证及归属声明。

---

<div align="center">

**Less noise. More signal.**

[Android 源码](https://github.com/NingSo/APS/tree/main) · [iOS 源码](https://github.com/NingSo/APS/tree/ios) · [版本发布](https://github.com/NingSo/APS/releases) · [问题反馈](https://github.com/NingSo/APS/issues)

</div>

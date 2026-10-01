# APS / SIGNAL iOS 版

[English](README.md) | 简体中文

这是 `ios` 分支上的**全新原生实现**。旧 `ios/Sources`、旧测试、旧生成工程及旧资源已移除，不在旧版上打补丁，也不以其作为视觉基线。参考的是你已验收的 Android 提交 `c2dd0a2616bbcf0b7f582c13c2d40316bba7dbfd`；Android 源码和 `proxycore` 不变，本次不修改 `main`。

## 构建

需要 macOS、带 iOS 模拟器的 Xcode、XcodeGen（`brew install xcodegen`）。应用无第三方包依赖，不包含签名密钥或字体文件。

```sh
bash ios/bootstrap.sh
open ios/APS.xcodeproj
```

脚本将已确认的矢量标志导出为不透明应用图标，并按 `project.yml` 生成 Xcode 工程；生成物已忽略。真机安装时由你选择开发团队，不要提交签名材料。

```sh
bash ios/scripts/ci.sh
```

GitHub 的 `iOS native build and tests` 工作流在推送 `ios` 时运行单元测试、本地 socket 集成测试和完整应用 UI 测试，保留 `Tests.xcresult`、截图、UI 测试录屏及模拟器应用。不是 App Store 发布，也不是可直接安装到 iPhone 的签名 IPA。

## 功能对齐

SwiftUI 实现概览、连接、活动三个主入口及设置、诊断二级页；包括原生双轨信号环（外圈 20 秒、内圈反向 38 秒）、真实速率曲线、配置复制/二维码/系统分享、端口校验、确认后导出日志、网络变化处理和偏好保存。尊重应用内和系统的减少动态效果设置；使用真实系统安全区，不绘制假的状态栏。弹层保留 iOS 原生交互式呈现/关闭行为，不承诺与 Android 逐帧相同。

Network.framework 实现 HTTP 转发、CONNECT 字节隧道和无鉴权 SOCKS5 TCP CONNECT。每个监听器都接受回环探测并回显随机标记之后，才进入运行状态。接收/发送统计分别指目标到客户端/客户端到目标转发的 TCP 字节，排除本地自检和代理握手回复，不是运营商计费流量。

代理使用增量、有界解析，写入完成后才继续读取以限制缓冲；设有启动/握手超时、120 秒空闲超时和 256 条客户端连接上限。修改配置先取消所有监听与连接，再重新绑定。停止清空内存会话，保留偏好；启动失败保留诊断原因，单次客户端错误不扩大为全局失败。

## iOS 平台边界

本版是前台局域网服务器：进入后台停止会话，回前台不自动开启。可选屏幕常亮仅在前台运行期间生效。没有静音音频/定位保活、Network Extension、VPN entitlement、热点管理、UDP、BIND、鉴权或设备识别。

提供 `NSLocalNetworkUsageDescription`。回环自检成功**不证明**局域网授权、其他设备可达或外网可达。诊断页不主动访问外部站点。发现网络变化会使分享/确认失效并停止服务，重新确认后才能开启；不增加额外平台信息时，系统未必能区分复用相同网卡和地址的新 Wi-Fi，请换网时重新确认可信性。

仅在可信局域网使用，不向公网映射端口。真实 iPhone/iPad 的 Wi-Fi、热点、VPN 路由、权限、无障碍和视觉保真仍需要真机验收。请查看 `VERIFICATION.zh-CN.md` 和对应 Actions 结果，不把测试源码当作已通过测试。

Apple 依据：[后台执行限制](https://developer.apple.com/forums/thread/685525)、[本地网络隐私](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)、[Network 接收 API](https://developer.apple.com/documentation/network/nwconnection/receive(minimumincompletelength:maximumlength:completion:))。

遵循仓库 Apache License 2.0，保留 Android 上游版权及 NOTICE，应用关于页展示 LICENSE。

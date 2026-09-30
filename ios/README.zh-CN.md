# APS / SIGNAL iOS 目标

这是 APS Android 代理的独立 SwiftUI 目标，保留 Android 源码及 15 个上游 `proxycore` 文件不变。

当前传输层使用 `Network.framework`，在前台提供局域网代理：

- HTTP 代理，支持绝对路径请求和 HTTPS `CONNECT` 隧道。
- SOCKS5 无鉴权 TCP `CONNECT`，支持 IPv4、域名和 IPv6。
- 不支持 UDP ASSOCIATE、BIND、鉴权、VPN 隧道、创建热点或自动修改系统代理。
- 监听所有本地接口，以便可信 Wi‑Fi 或个人热点中的其他设备接入。应用不会自动打开 Wi‑Fi 或个人热点。

`ProtocolModels.swift` 对齐 Android 的 `ProxySettings`、`SessionPhase`、运行计数和日志模型。`ProxyServer.swift` 管理监听器生命周期并发出连接/字节事件；SwiftUI ViewModel 使用这些事件驱动概览、连接和活动页面。

## 生成和构建

项目定义使用 XcodeGen 管理，便于审阅：

```sh
xcodegen generate --spec ios/project.yml
xcodebuild -project ios/APS.xcodeproj -scheme APS -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /tmp/aps-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project ios/APS.xcodeproj -scheme APS -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -derivedDataPath /tmp/aps-ios-derived CODE_SIGNING_ALLOWED=NO
```

这些命令只编译模拟器目标。声称 iOS 验收前仍需真机运行及跨设备 HTTP/SOCKS5 转发测试。本前台目标不承诺锁屏后持续运行；若需要后台长期监听，必须另行设计 Network Extension 方案。

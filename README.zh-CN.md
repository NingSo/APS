# APS / SIGNAL — iOS

[English](README.md) | 简体中文

此分支只包含原生 iOS 实现。应用使用 SwiftUI 和 Network.framework，提供前台局域网 HTTP / SOCKS5 TCP 代理服务。

## 构建

```sh
bash ios/bootstrap.sh
bash ios/scripts/ci.sh
```

引导脚本会生成 `ios/APS.xcodeproj`。CI 脚本在可用模拟器上执行 iOS 单元测试、本地代理集成测试和 UI 测试。真机签名构建需要本地 Apple 开发团队与 provisioning profile，仓库不会提交签名材料。

实现限制和验收证据见 [ios/README.zh-CN.md](ios/README.zh-CN.md) 与 [ios/VERIFICATION.zh-CN.md](ios/VERIFICATION.zh-CN.md)。

## 范围

此分支不包含 Android 应用或 Android 代理核心。服务仅在前台运行，支持 HTTP 转发、HTTPS `CONNECT` 和无认证 SOCKS5 TCP `CONNECT`；不提供 VPN、热点管理、UDP、BIND、身份认证或后台持续监听。

只应在可信局域网使用。环回自检不能证明其他设备或外网已经可达。

采用 Apache License 2.0，详见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

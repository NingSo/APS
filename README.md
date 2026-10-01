# APS / SIGNAL — iOS

English | [简体中文](README.zh-CN.md)

This branch contains the native iOS implementation only. The app is a foreground LAN HTTP / SOCKS5 TCP proxy built with SwiftUI and Network.framework.

## Build

```sh
bash ios/bootstrap.sh
bash ios/scripts/ci.sh
```

The bootstrap generates `ios/APS.xcodeproj`. The CI script runs the iOS unit, local proxy integration and UI tests on an available simulator. A signed device build requires a local Apple development team and provisioning profile; signing material is never committed.

Read [ios/README.md](ios/README.md) and [ios/VERIFICATION.md](ios/VERIFICATION.md) for the implementation limits and acceptance evidence.

## Scope

This branch does not contain the Android application or Android proxy core. The server is foreground-only and supports HTTP forwarding, HTTPS `CONNECT` and unauthenticated SOCKS5 TCP `CONNECT`. It does not provide VPN, hotspot management, UDP, BIND, authentication or background listener persistence.

Use the proxy only on a trusted local network. A loopback self-test does not prove remote-client or Internet reachability.

Licensed under Apache License 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).

# APS / SIGNAL iOS target

This directory is an independent SwiftUI target for the APS Android proxy companion. It keeps the Android source and the 15 upstream `proxycore` files untouched.

The current transport target is a foreground LAN proxy built on `Network.framework`:

- HTTP proxy with absolute-form requests and HTTPS `CONNECT` tunnelling.
- SOCKS5 no-auth TCP `CONNECT` for IPv4, domain and IPv6 requests.
- No UDP associate, BIND, authentication, VPN tunnel, hotspot creation or automatic system-proxy configuration.
- Listeners bind to all local interfaces so another trusted Wi‑Fi or Personal Hotspot client can use the phone as the proxy. The app does not turn either network on.

`ProtocolModels.swift` mirrors the Android `ProxySettings`, `SessionPhase`, runtime counters and log model. `ProxyServer.swift` owns listener lifecycle and emits connection/byte events; the SwiftUI view model consumes those events for the Overview, Connect and Activity screens.

## Generate and build

XcodeGen is used to keep the project definition reviewable:

```sh
xcodegen generate --spec ios/project.yml
xcodebuild -project ios/APS.xcodeproj -scheme APS -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /tmp/aps-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project ios/APS.xcodeproj -scheme APS -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -derivedDataPath /tmp/aps-ios-derived CODE_SIGNING_ALLOWED=NO
```

These commands compile for the simulator only. A real-device run and cross-device HTTP/SOCKS5 transfer test are still required before claiming iOS acceptance. iOS background persistence is intentionally not implied by this foreground target; a later Network Extension design is needed for lock-screen operation.

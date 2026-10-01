# APS / SIGNAL for iOS

English | [简体中文](README.zh-CN.md)

This is a **new native implementation** on the `ios` branch. The old `ios/Sources`, tests, generated project and assets were removed, not patched or used as the design baseline. Android at `c2dd0a2616bbcf0b7f582c13c2d40316bba7dbfd` is the approved product reference; Android source and `proxycore` remain untouched. The `main` branch is not changed by this delivery.

## Build

Requires macOS, Xcode with an iOS simulator, and XcodeGen (`brew install xcodegen`). No third-party application package dependencies, signing secrets or embedded fonts are required.

```sh
bash ios/bootstrap.sh
open ios/APS.xcodeproj
```

The bootstrap exports the approved vector logo to an opaque app icon and generates the Xcode project from `project.yml`. Generated files are intentionally ignored. Set your own development team only for installation on a physical device; do not commit signing material.

```sh
bash ios/scripts/ci.sh
```

The `iOS native build and tests` GitHub workflow runs on pushes to `ios`. It runs unit, local-socket integration and full-app UI tests, retaining `Tests.xcresult`, screenshots, a UI-test recording and the simulator application. This is not an App Store release or an installable signed iPhone IPA.

## Product parity

SwiftUI implements the three main tabs (overview, connection, activity), secondary settings/diagnostics, the native two-track signal orbit (20-second outer rotation, reverse 38-second middle rotation), real rate charts, configuration copy/QR/system sharing, port validation, user-confirmed log export, network-change handling and saved preferences. Both app and system reduce-motion preferences are respected. The interface has real safe areas, not simulated system bars. Native sheets deliberately retain iOS interactive presentation/dismissal behavior; this is not a promise of frame-identical Android transitions.

Network.framework implements HTTP forwarding, CONNECT byte tunnels and unauthenticated SOCKS5 TCP CONNECT. The state only becomes running after every listener accepts a loopback probe and echoes a random per-start marker. Receive/send counters measure forwarded target-to-client/client-to-target TCP bytes, excluding local self-tests and proxy handshake replies. These are not carrier-billing statistics.

The relay uses incremental bounded parsing, send-completion backpressure, startup/handshake timeouts, a 120-second idle timeout and a 256-client limit. Configuration changes cancel all listeners/connections before rebind. Stop clears the in-memory session; preferences remain. Failed startup leaves diagnostic errors. Nonfatal client errors remain warnings rather than globally failing the service.

## iOS-specific limits

This is a foreground-only LAN server. Going to the background stops the session; foreground return never starts it automatically. Optional screen-awake mode only affects foreground running sessions. No silent-audio/location workaround, Network Extension, VPN entitlement, hotspot management, UDP, BIND, authentication or device identity is claimed.

`NSLocalNetworkUsageDescription` is supplied. A successful loopback self-test does **not** prove local-network permission, remote-client reachability or Internet reachability. The diagnostics page does not issue external probe requests. Network changes invalidate sharing/consent and stop serving until a new confirmation. A new Wi-Fi network reusing the same interface and address cannot always be distinguished without additional platform information; reconfirm trust when changing networks.

Use only on a trusted LAN. Do not port-forward the listener to the Internet. Real iPhone/iPad Wi-Fi, hotspot reachability, VPN routing, permissions, accessibility and visual fidelity still require device acceptance. Review `VERIFICATION.md` and the exact Actions result rather than interpreting test source as passed tests.

Apple references: [Background execution limits](https://developer.apple.com/forums/thread/685525), [Local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [Network receive](https://developer.apple.com/documentation/network/nwconnection/receive(minimumincompletelength:maximumlength:completion:)).

Licensed under the repository Apache License 2.0. The Android upstream credit and repository NOTICE are preserved. The in-app About page includes LICENSE.

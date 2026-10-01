<div align="center">

# APS / SIGNAL

**Your mobile device. A native proxy. A clearer connection.**

HTTP · HTTPS CONNECT · SOCKS5 TCP  
Android · iOS / iPadOS

[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#download)
[![iOS](https://img.shields.io/badge/iOS%20%2F%20iPadOS-16.0%2B-111827?style=flat-square&logo=apple&logoColor=white)](#download)
[![Native UI](https://img.shields.io/badge/UI-Compose%20%2B%20SwiftUI-B8F568?style=flat-square&labelColor=161C19)](#experience)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)

**English** · [简体中文](README.zh-CN.md)

[Download](#download) · [Experience](#experience) · [Features](#features) · [Platform support](#support) · [Architecture](#architecture) · [Quick start](#quick-start) · [Clash Verge](#clash-verge) · [Development](#development) · [Credits](#credits)

</div>

---

**APS turns an Android device, iPhone or iPad into a local HTTP / SOCKS5 proxy server.** Connect a proxy-aware browser, command-line tool or application on a trusted LAN, then inspect the session from a native interface: start and stop listeners, share connection details, follow live traffic and diagnose connection problems.

Originally derived from **Android Proxy Server**, APS now brings the **SIGNAL** experience to two independent native implementations: **Kotlin / Jetpack Compose** on Android and **Swift / SwiftUI** on iOS. It is a proxy server on your device—not a VPN subscription, remote node provider or WebView wrapper.

**Typical setup:** run APS on the phone and [connect from computer Clash Verge](#clash-verge) using SOCKS5 or HTTP. Requests can also use the phone's VPN exit when that VPN covers APS and the destination.

This `main` branch is the project landing page and Android source. The independent iOS application lives on the [`ios` branch](https://github.com/NingSo/APS/tree/ios).

<a id="download"></a>
## Download

| Platform | Published package | Requirements | Installation |
| --- | --- | --- | --- |
| **Android** | **[1.0.0 · Stable release](https://github.com/NingSo/APS/releases/tag/android-v1.0.0)** | Android 8.0+ / API 26+ | **[Download signed APK](https://github.com/NingSo/APS/releases/download/android-v1.0.0/APS-Android-1.0.0.apk)** |
| **iOS / iPadOS** | **[1.0.0 · Unsigned device build](https://github.com/NingSo/APS/releases/tag/ios-v1.0.0-preview.1)** | iOS / iPadOS 16.0+ | **[Download IPA · signing required](https://github.com/NingSo/APS/releases/download/ios-v1.0.0-preview.1/APS-iOS-1.0.0-unsigned.ipa)** |

> [!IMPORTANT]
> **The iOS IPA requires valid signing and provisioning before installation.** It is an arm64 iPhoneOS Release build, not a simulator archive, but downloading it in Safari does not install it. No TestFlight or App Store distribution is currently provided. See the [iOS installation and release guide](https://github.com/NingSo/APS/blob/ios/ios/RELEASES.md).

Android 1.0.0 is a non-debuggable Release build with package ID `com.ningso.aps`. It can coexist with the older `com.ningso.aps.debug` test app; settings do not migrate automatically. Do not run both copies on the same proxy ports.

Each release includes installation notes, build provenance and SHA-256 checksums. Choose the `.apk` or `.ipa` asset—not GitHub's automatically generated **Source code** archives. See [all releases](https://github.com/NingSo/APS/releases).

<a id="experience"></a>
## The SIGNAL experience

A near-black canvas, lime accents, native signal orbits and readable network values keep the next action clear. The interface follows three primary destinations—**Overview**, **Connect** and **Activity**—with **Settings** and **Diagnostics** available when needed.

| Overview · control the session | Connect · configure the client |
| :---: | :---: |
| <img src="docs/APS-SIGNAL/screens/01-overview.webp" alt="SIGNAL design reference: overview with signal orbit, traffic and local address" width="300"> | <img src="docs/APS-SIGNAL/screens/02-connect.webp" alt="SIGNAL design reference: protocol, address, port and client setup guidance" width="300"> |

*SIGNAL design-reference images; addresses and metrics are illustrative, not live device data. The two native apps follow this visual language while retaining platform-specific controls, safe areas and sheet behavior.*

The signal orbit is drawn with **native Canvas APIs**, not an embedded animation movie or web page. Both implementations provide reduced-motion behavior; an animated ring is never used as a substitute for actual listener state.

<a id="features"></a>
## Features

| Capability | What you can do |
| --- | --- |
| **HTTP & SOCKS5 proxying** | Forward HTTP requests, tunnel HTTPS with HTTP `CONNECT`, and relay SOCKS5 TCP `CONNECT` traffic. Enable either protocol or both. |
| **Explicit session control** | Start and stop deliberately, review trusted-network consent, and distinguish standby, starting, running, stopping and failure states. Opening the app does not start a server. |
| **Connection setup, in one place** | View detected LAN IPv4 addresses, choose the client-facing address, copy host/port details, generate a configuration QR code and use native system sharing. |
| **Live session visibility** | Inspect receive/send rates, cumulative traffic, active connections and total connections. Rates are sampled each second, with up to 60 chart samples retained. |
| **Configuration & diagnostics** | Edit protocol ports with range/conflict validation, save preferences, inspect local listener status and follow platform-specific network/background guidance. |
| **Searchable session logs** | Search and filter up to 200 in-memory log entries and explicitly export them. Stop clears the in-memory session, while protocol preferences remain saved. |

Configuration changes made during a running session rebuild listeners and interrupt existing connections. The editor makes that interruption explicit. A successful local listener check is **not** a claim that a remote client or Internet destination is reachable.

<a id="support"></a>
## Platform support

| Area | Android | iOS / iPadOS |
| --- | --- | --- |
| Native interface | Jetpack Compose + Canvas | SwiftUI + Canvas |
| Networking engine | Netty-based upstream `proxycore` | Independent `Network.framework` implementation |
| HTTP forwarding / HTTPS via `CONNECT` | Supported | Supported |
| SOCKS5 TCP `CONNECT` | Supported | Supported |
| Client connection address | Detected LAN IPv4 address | Detected LAN IPv4 address; local-network access required |
| QR, copy, sharing, traffic, logs | Supported | Supported |
| Background / lock-screen use | Foreground service; subject to Android and vendor battery policies | **Foreground only**; backgrounding or locking stops the session |
| Screen-awake option | No dedicated screen-awake toggle | Optional while the app is foregrounded and the proxy is running |
| Network changes | Refreshes addresses and prompts for updated client configuration | Detected changes invalidate consent/sharing and stop the session |
| Default ports | HTTP `8080` · SOCKS5 `1080` | HTTP `8080` · SOCKS5 `1080` |
| Distributed package | Signed, non-debuggable APK | Unsigned device IPA; re-signing required |

**Client compatibility.** Windows, macOS, Linux, Android and iOS applications can connect when they support the selected proxy protocol and can reach the host device. Configuring a system proxy does not guarantee that every application uses it. Wi-Fi client isolation, firewalls, hotspot policies and VPN app exclusions can affect connectivity.

**Outside the current scope.** No SOCKS5 UDP/BIND, proxy authentication, built-in VPN tunnel, hotspot creation, automatic client configuration, connected-device inventory or cloud relay. QR codes contain configuration text; they do not silently modify a client's system settings. Connection counts are **TCP connections, not device counts**. IPv6-only client networks are not claimed as a supported connection setup.

<a id="architecture"></a>
## Architecture

**One product experience; two native implementations.** Clients connect to one host platform. User-interface controls manage that platform's listeners; proxy traffic follows the host operating system's routing to the destination.

```mermaid
flowchart LR
    client["LAN client<br/>Browser, CLI or proxy-aware app"]
    subgraph android["Android · main"]
        direction TB
        aui["Jetpack Compose + Canvas"] -->|Control| astate["ProxyViewModel + ProxyService"]
        astate -->|Lifecycle| acore["Netty / upstream proxycore"]
    end
    subgraph ios["iOS · ios branch"]
        direction TB
        iui["SwiftUI + Canvas"] -->|Control| istate["AppStore"]
        istate -->|Lifecycle| icore["ProxyEngine / Network.framework"]
    end
    client -->|HTTP / SOCKS5 TCP| acore
    client -->|HTTP / SOCKS5 TCP| icore
    acore -->|Android routing| target["Destination service"]
    icore -->|iOS routing| target
```

Android preserves the upstream Kotlin proxy core; iOS does **not** execute that core or share the Android runtime. There is no APS cloud service between the host device and the destination.

### Interaction flow

The task flow is designed around **start → connect → observe**, with configuration and diagnostics available to resolve failures.

```mermaid
flowchart LR
    lan["Join a trusted LAN"] --> config["Choose protocol and port"]
    config --> consent["Confirm and start"]
    consent --> ready{"Local listeners ready?"}
    ready -->|Yes| setup["Configure a client"]
    setup --> activity["Observe traffic and logs"]
    ready -->|No| diagnose["Inspect diagnostics and settings"]
    diagnose --> config
```

<a id="quick-start"></a>
## Quick start

1. **Connect to a trusted network.** The client must be able to reach the Android device, iPhone or iPad. Allow iOS local-network access when prompted.
2. **Choose and start.** Enable HTTP, SOCKS5 or both, confirm the ports, review the trust notice and start the proxy. Keep the iOS app in the foreground.
3. **Configure the client.** Use the address displayed in APS and the matching protocol port. Do not enter `0.0.0.0`; it is a bind address, not a client destination. Leave proxy authentication off.
4. **Verify an actual request.** Check the client response and the Activity screen. If it fails, inspect routing, client isolation, permissions, ports and logs rather than relying on the running indicator alone.

For a command-line client, replace the **documentation-only address** `192.0.2.10` with the address shown by your host device:

```sh
# HTTPS through the HTTP CONNECT proxy
curl --proxy http://192.0.2.10:8080 https://example.com

# SOCKS5 TCP; the proxy resolves the destination hostname
curl --proxy socks5h://192.0.2.10:1080 https://example.com
```

<a id="clash-verge"></a>
## Use the phone's connection with Clash Verge

**Run APS on the phone and Clash Verge on the computer; APS opens outbound connections for the computer's proxied requests.** The devices must be reachable over a trusted LAN, such as the same Wi-Fi. A phone hotspot is also subject to actual reachability. This uses the network route selected for APS by the phone, **not necessarily cellular data**, and does not attach the computer directly to the phone's VPN interface.

```text
Computer app → Clash Verge on computer → APS on phone (SOCKS5 / HTTP)
                                                ↓
                                     Phone OS and VPN routing policy
                                                ↓
                                  VPN exit or ordinary network → Destination
```

### Connect the two devices

1. **On the phone.** Enable SOCKS5 (default `1080`) or HTTP (default `8080`), confirm the trusted network and start APS. Note its displayed LAN address. When using a phone VPN, connect it first, then return to APS and start the proxy. Keep APS foregrounded on iOS.
2. **On the computer.** This example uses **Clash Verge Rev / Mihomo** configuration syntax. Create a separate local (Local) profile in the profiles/subscriptions page, paste the complete configuration below or import the saved YAML, then activate that profile. No paid or remote subscription is required for this setup.
3. **Select the outbound.** Use rule mode and choose an enabled `APS-SOCKS5` or `APS-HTTP` node in the `APS` group. For the first browser test, leave computer TUN mode off and enable system proxy. Adding a node without selecting it through the active rules/group does not route traffic to it.

<details>
<summary><strong>Complete local profile</strong> — choose SOCKS5 or HTTP</summary>

**Replace both occurrences of `192.0.2.10` with the phone's actual APS address** and use its configured ports. That address is documentation-only. This is a standalone profile, not a replacement for an existing subscription; do not duplicate top-level `proxies`, `proxy-groups` or `rules` keys.

```yaml
mixed-port: 7897
allow-lan: false
mode: rule
log-level: info
tun:
  enable: false

proxies:
  - name: APS-SOCKS5
    type: socks5
    server: 192.0.2.10
    port: 1080
    udp: false
  - name: APS-HTTP
    type: http
    server: 192.0.2.10
    port: 8080
    tls: false

proxy-groups:
  - name: APS
    type: select
    proxies:
      - APS-SOCKS5
      - APS-HTTP

rules:
  - MATCH,APS
```

`1080` / `8080` are the **upstream APS ports on the phone**; `7897` is the **local Clash mixed proxy port on the computer**. They are different endpoints. Clash Verge settings or overrides may change the local port; use the effective configuration. `allow-lan: false` prevents other devices from using the computer's Clash inbound; it does not stop the computer connecting to APS.

APS requires no proxy username/password. HTTP `tls: false` still allows HTTPS destinations through `CONNECT`; it only disables an extra TLS layer to the APS proxy endpoint. SOCKS5 `udp: false` reflects APS's current TCP-only support.

`MATCH,APS` sends **proxyable TCP requests that enter Clash** to the selected APS node, not every packet from the computer. For an existing profile, merge the nodes/group and route the intended rules to `APS`; existing `DIRECT` rules may still send some requests directly from the computer.

</details>

### Can the computer use the phone's VPN exit?

**Yes, provided the phone VPN captures APS's outbound connections and routes the requested destination through its tunnel.** APS neither supplies a VPN tunnel nor forces another VPN's routing policy. This condition applies to both HTTP and SOCKS5; it is not a SOCKS5-only feature.

| Check | What it means |
| --- | --- |
| Phone VPN coverage | Android per-app settings must include the actual APS app, rather than exclude or bypass it. The stable package is `com.ningso.aps`; the older debug package is `com.ningso.aps.debug`. A browser-only proxy or a work-profile-only VPN does not imply coverage of APS in the personal profile. |
| Two routing decisions | Computer Clash first decides whether to send a request to APS; the phone VPN then decides whether APS's destination connection uses its tunnel. Split-tunnel/rule mode can still send some destinations directly. |
| LAN reachability | VPN LAN blocking, OS lockdown, Wi-Fi client isolation or hotspot policies can prevent the computer reaching APS. Allow necessary trusted-LAN communication according to the VPN's instructions; do not disable security protections indiscriminately. |
| iOS lifecycle | Connect the VPN first, return to APS, start and stay foregrounded. Switching to the VPN app, locking or backgrounding stops APS. Routing compatibility with a particular VPN needs physical-device verification. |
| Traffic and disconnect boundaries | APS has no UDP/BIND support; computer TUN mode does not add it. DNS routing depends on the client's resolver choices. APS has no independent VPN kill switch: new connections may use ordinary OS routes after VPN disconnection. Configure and verify the phone VPN/OS blocking policy when fallback is unacceptable. |

### Verify the actual exit, not just the VPN icon

First bypass computer Clash to test **computer → phone APS**; then test **computer → Clash → phone APS**. The following commands deliberately contact third-party [ipify](https://www.ipify.org/) for the public IPv4 of that request; substitute your own exit-check service if preferred. Replace the phone address and use the effective Clash local port in the second command. In Windows PowerShell, use `curl.exe` to avoid alias differences.

```sh
# Direct to phone SOCKS5; socks5h asks the phone to resolve the destination
curl --noproxy "" --proxy socks5h://192.0.2.10:1080 --connect-timeout 10 --max-time 20 https://api.ipify.org

# Through computer Clash, then its selected APS node
curl --noproxy "" --proxy http://127.0.0.1:7897 --connect-timeout 10 --max-time 20 https://api.ipify.org
```

Also inspect APS counters, the selected computer Clash outbound and any destination-routing logs the phone VPN provides. **The test destination must be selected for tunneling by the phone VPN.** The expected VPN exit is evidence for that request. The phone browser may follow different rules, so comparing browser IPs alone is insufficient; one successful exit check does not prove routing for other destinations, DNS or UDP.

Configuration references: [Mihomo SOCKS5](https://wiki.metacubex.one/config/proxies/socks/), [HTTP](https://wiki.metacubex.one/config/proxies/http/), [routing rules](https://wiki.metacubex.one/config/rules/), [Clash Verge local profiles](https://www.clashverge.dev/guide/profile.html), [system proxy and TUN](https://www.clashverge.dev/guide/quickstart.html), [Android per-app VPN and routing](https://developer.android.com/develop/connectivity/vpn#per-app), [curl proxy options](https://curl.se/docs/manpage.html#--proxy).

<a id="security"></a>
## Security & privacy

> [!WARNING]
> **Use APS only on a trusted LAN. The listeners are unauthenticated.** Do not expose their ports through public port forwarding or treat this app as an authenticated Internet proxy. Selecting a client-facing address is not an access-control rule.

APS has no app accounts, advertisements, built-in telemetry or automatic log uploads. Sessions are local, but **the traffic you explicitly proxy still reaches its intended network destinations**. Exported logs may contain network details and persist wherever you save or share them.

HTTPS `CONNECT` carries the client's TLS session; it does not turn every proxy connection into encrypted transport. Plain HTTP remains plain HTTP. APS neither provides anonymity nor overrides the host operating system's routing or VPN rules.

On iOS, stopping on background entry is an intentional lifecycle boundary, not a hidden keep-alive workaround. See Apple's [background execution guidance](https://developer.apple.com/forums/thread/685525) and [signed device distribution requirements](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

<a id="development"></a>
## Development

### Repository layout

The platform branches are deliberately independent. Use separate working directories when developing both; do not merge the iOS-only directory layout wholesale into the Android branch.

| Branch | Role | Main paths |
| --- | --- | --- |
| [`main`](https://github.com/NingSo/APS/tree/main) | Project homepage, Android source and Android releases | `app/`, `proxycore/`, `gradle/`, `scripts/`, `docs/` |
| [`ios`](https://github.com/NingSo/APS/tree/ios) | iPhone/iPad source, native tests and IPA packaging | `ios/APS/`, `ios/Tests/`, `ios/UITests/`, `ios/Support/`, `ios/scripts/` |

<details>
<summary><strong>Build Android</strong> — JDK 21, Android SDK 36, Python 3.11+</summary>

Install Android SDK Platform 36 and Build Tools 36.0.0; set `ANDROID_HOME` or a local `sdk.dir`. Toolchain versions are pinned in [`gradle/libs.versions.toml`](gradle/libs.versions.toml) and the wrapper properties.

```sh
git clone --branch main --single-branch https://github.com/NingSo/APS.git APS-android
cd APS-android
python3 scripts/bootstrap_gradle.py
./gradlew :proxycore:testDebugUnitTest :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

The bootstrap retrieves the pinned wrapper JAR and checks its Git blob hash. Dependency resolution requires network access. On Windows, use `python` and `gradlew.bat` with the same tasks.

The local debug APK is `app/build/outputs/apk/debug/app-debug.apk`; it is separate from the signed stable release. For production builds and continuity of the established signing certificate, follow the [Android release guide](docs/RELEASES.md). Do not generate a replacement key for an existing application identity.

</details>

<details>
<summary><strong>Build iOS / iPadOS</strong> — macOS, Xcode, Python 3 and XcodeGen</summary>

Use Xcode with a compatible installed iOS simulator and make `xcodegen` available on your path.

```sh
git clone --branch ios --single-branch https://github.com/NingSo/APS.git APS-ios
cd APS-ios
bash ios/bootstrap.sh
open ios/APS.xcodeproj

# Native compilation, local proxy tests and full-app UI tests
bash ios/scripts/ci.sh
```

The Xcode project and app icons are generated by the bootstrap. For a physical device, select your own development team and configure valid signing/provisioning in Xcode. No third-party application package dependencies are required. Packaging an IPA alone does not make it installable without signing.

See the [iOS source](https://github.com/NingSo/APS/tree/ios/ios) and [iOS release guide](https://github.com/NingSo/APS/blob/ios/ios/RELEASES.md).

</details>

### Verification & releases

[Android CI](https://github.com/NingSo/APS/actions/workflows/android.yml) covers source checks, the configured unit tests, Lint and debug packaging. The separate [Android release workflow](https://github.com/NingSo/APS/blob/main/.github/workflows/release-android.yml) validates the Release build, package/version, certificate and ZIP alignment before publication. [Android native UI checks](https://github.com/NingSo/APS/actions/workflows/native-ui.yml) are manually dispatched.

The [iOS workflow](https://github.com/NingSo/APS/blob/ios/.github/workflows/ios.yml) runs native compilation, unit/local-proxy integration tests and full-app UI tests; requested IPA publication is gated on those checks. Test results, screenshots and recordings are retained as Actions artifacts. Release pages identify the exact source revision and build run. A CI result is evidence for that run—not a blanket guarantee for every device, network or visual configuration.

### Contributing

Open an [issue](https://github.com/NingSo/APS/issues) with the platform, OS/app version, device model and reproducible steps. Target Android changes at `main` and iOS changes at `ios`, keep changes focused, and include relevant tests. Redact private network details before sharing logs. Never commit signing keys, passwords or provisioning material.

<a id="credits"></a>
## Credits & license

**Special thanks to [hect0x7](https://github.com/hect0x7) and [android-proxy-server](https://github.com/hect0x7/android-proxy-server)** for the Android proxy foundation. APS's Android app builds on that foundation with the SIGNAL interface and application orchestration. Its iOS app is implemented independently in Swift.

The **15 original Kotlin core files** remain pinned to upstream commit [`a785282`](https://github.com/hect0x7/android-proxy-server/commit/a785282cf172112590e992165090b4729d5f64dc). Their blob hashes are recorded in [`upstream-lock.json`](upstream-lock.json) and verified by [`scripts/check_source.py`](scripts/check_source.py).

We also acknowledge the **Android Open Source Project / Jetpack Compose**, **JetBrains / Kotlin**, **Kotlin Coroutines**, **Netty**, **SLF4J** and **ZXing** communities. The iOS implementation uses Apple's **SwiftUI**, **Network.framework** and **Core Image** platform frameworks; it is not a port of the Kotlin runtime.

APS source is available under the **[Apache License 2.0](LICENSE)**. The upstream **Copyright 2026 hect0x7** attribution and **[NOTICE](NOTICE)** are retained. Third-party components remain subject to their respective licenses and notices; the project license does not replace those terms. Please retain the applicable license and attribution notices when redistributing the project.

---

<div align="center">

**Less noise. More signal.**

[Android source](https://github.com/NingSo/APS/tree/main) · [iOS source](https://github.com/NingSo/APS/tree/ios) · [Releases](https://github.com/NingSo/APS/releases) · [Report an issue](https://github.com/NingSo/APS/issues)

</div>

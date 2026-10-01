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

[Download](#download) · [Use case](#clash-verge) · [Features](#features) · [Interface](#experience) · [Support](#support) · [Documentation](#documentation) · [Credits](#credits)

</div>

---

**APS turns your Android device, iPhone or iPad into a local HTTP / SOCKS5 proxy.** Connect a computer to the phone's network route, share proxy settings and watch the session in a native interface.

Android uses Jetpack Compose; iOS uses SwiftUI. APS is a proxy server, not a VPN client or a remote node service. Android source is on [`main`](https://github.com/NingSo/APS/tree/main); iOS source is on [`ios`](https://github.com/NingSo/APS/tree/ios).

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

<a id="clash-verge"></a>
## Use case: VPN on your phone, access from your computer

**Keep the VPN on your phone; use Clash Verge on your computer to connect through APS.** Where your organization permits forwarding and the phone VPN routes APS's destination connections through its tunnel, the computer can access authorized services without installing the same VPN client again.

```text
Computer (Clash Verge) → Phone APS → Phone VPN → Authorized intranet / website
```

The maintainer reports successful use in company-permitted environments including aTrust. This describes specific tested deployments, not universal vendor compatibility. Without a VPN, APS follows the phone's ordinary network routes.

<a id="quick-start"></a>
### Four steps

1. **Phone:** connect the VPN when needed, return to APS, start SOCKS5 or HTTP and note the phone address and port.
2. **Computer:** save the [example profile](docs/examples/APS-Clash-Verge.yaml), replace both example IPs with the phone address and import it as a separate Clash Verge local profile.
3. **Select APS:** enable the profile, select the phone's enabled node in the `APS` group and turn on system proxy.
4. **Use it:** open an authorized destination in a browser that follows system proxy and check APS traffic.

The devices must be reachable on the same trusted network; the phone VPN must cover APS and the destination. Keep APS foregrounded on iPhone/iPad. This does not capture all computer traffic or replace company login/device-compliance requirements. See the [complete setup and troubleshooting guide](docs/CLASH-VERGE.md).

<a id="features"></a>
## Features

| Capability | What you can do |
| --- | --- |
| **HTTP & SOCKS5** | HTTP forwarding, HTTPS via CONNECT and SOCKS5 TCP CONNECT; enable either protocol or both. |
| **Session control** | Explicit start/stop, trusted-network confirmation and real service states. |
| **Connection sharing** | LAN address selection, host/port copy, configuration QR and native sharing. |
| **Live traffic** | Receive/send rates, cumulative traffic, active and total TCP connections. |
| **Settings & diagnostics** | Port validation, saved preferences and local listener checks. |
| **Session logs** | Search, filter and user-triggered export. |

<a id="experience"></a>
## Interface

A near-black canvas, lime accents, native signal orbits and readable network values keep the next action clear. The interface follows three primary destinations—**Overview**, **Connect** and **Activity**—with **Settings** and **Diagnostics** available when needed.

| Overview · control the session | Connect · configure the client |
| :---: | :---: |
| <img src="docs/APS-SIGNAL/screens/01-overview.webp" alt="SIGNAL design reference: overview with signal orbit, traffic and local address" width="300"> | <img src="docs/APS-SIGNAL/screens/02-connect.webp" alt="SIGNAL design reference: protocol, address, port and client setup guidance" width="300"> |

*SIGNAL design-reference images; addresses and metrics are illustrative, not live device data. The two native apps follow this visual language while retaining platform-specific controls, safe areas and sheet behavior.*

The signal orbit is drawn with **native Canvas APIs**, not an embedded animation movie or web page. Both implementations provide reduced-motion behavior; an animated ring is never used as a substitute for actual listener state.

<a id="support"></a>
## Platform support

| Area | Android | iOS / iPadOS |
| --- | --- | --- |
| Minimum OS | Android 8.0+ | iOS / iPadOS 16.0+ |
| Native interface | Jetpack Compose + Canvas | SwiftUI + Canvas |
| Protocols | HTTP / HTTPS CONNECT / SOCKS5 TCP | HTTP / HTTPS CONNECT / SOCKS5 TCP |
| Background use | Foreground service, subject to system/battery policies | Foreground only; backgrounding or locking stops APS |
| Default ports | HTTP `8080` · SOCKS5 `1080` | HTTP `8080` · SOCKS5 `1080` |

Clients must support the selected proxy protocol and reach the phone's LAN IPv4 address. APS does not provide UDP/BIND, a built-in VPN, hotspot creation or automatic client configuration. Connection counts are not device counts.

> Use only on an authorized, trusted LAN: APS has no proxy authentication; never expose its ports to the public internet.

<a id="documentation"></a>
## Documentation

[Clash Verge setup & troubleshooting](docs/CLASH-VERGE.md) · [Architecture, behavior & development](docs/TECHNICAL.md) · [Android releases](docs/RELEASES.md) · [iOS releases](https://github.com/NingSo/APS/blob/ios/ios/RELEASES.md) · [Issues](https://github.com/NingSo/APS/issues)

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

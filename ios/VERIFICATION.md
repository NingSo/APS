# iOS implementation verification

English | [简体中文](VERIFICATION.zh-CN.md)

## Baseline and scope

Reference: Android and shared visual resources at `c2dd0a2616bbcf0b7f582c13c2d40316bba7dbfd`. Android acceptance is reported by the owner, not repeated in this iOS task. This branch replaces the old iOS tree and adds only iOS source, tests, documentation and `.github/workflows/ios.yml`.

## Gates

1. Offline scope, privacy-manifest and source checks must pass.
2. Xcode must compile the app, unit-test bundle and UI-test runner at deployment target iOS 16.
3. Unit/local socket tests must cover parsing, partial/coalesced handshakes, malformed input, protocol replies, counters, actual forwarding, half-close draining, occupied ports, reconfiguration and stop.
4. Full-app UI tests must cover three-tab navigation, risk confirmation, invalid/valid port edits, no-address/failed states, QR sharing and log filtering. Screenshot attachments are fixtures, not live-network claims.
5. Visual review must compare matching screenshots with the approved Android reference. Motion frame captures/recording are not frame-rate measurements.
6. Physical-device permissions, alternate networks, hotspot/VPN behavior, background/lock-screen transitions and accessibility need separate acceptance.

At source authoring time gates 2–6 are pending. The exact workflow result is authoritative. A generated simulator app is not a signed device build or a release.

No developer token, signing key, real network capture or font asset is included. Only user-requested sharing/export leaves the app. The self-test is loopback-only and no diagnostic sends Internet probe traffic.

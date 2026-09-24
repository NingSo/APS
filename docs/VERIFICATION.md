# Implementation and verification record

English | [简体中文](VERIFICATION.zh-CN.md)

## What was changed

The 15 main proxycore Kotlin files are unchanged from the pinned upstream commit. The application module has new model, view-model, foreground-service orchestration and Compose presentation code. `upstream-lock.json` provides file-level provenance; this handoff is a new repository import, not a copy of the complete upstream Git history.

| Area | Implementation |
| --- | --- |
| Runtime state | Explicit phases and actual listener configuration; preference flags alone never mean running |
| Session ownership | A generation token prevents a destroyed service from overwriting its successor |
| Service lifecycle | Serialized commands, real listener self-tests, nonsticky user activation, partial wake lock, stop action in notification |
| Reconfiguration | Warn before rebuilding all listeners; reject invalid/duplicate ports; roll back a platform-rejected request |
| Live display | Real 1-second byte deltas using monotonic time; at most 60 samples; connection counts, not device identities |
| Sharing | Current address/port text QR, real clipboard and Android chooser; changing address invalidates open sharing/consent |
| Permissions | Risk confirmation precedes activation; notification permission does not itself mean network trust; check the address again after permission result |
| Native navigation | Three primary tabs, settings and diagnostics; safe insets; saved tab/editor UI state; animation only in foreground when permitted |
| Logging | Bounded memory log, separate INFO/WARN/ERROR; explicit export confirmation; no remote logging |

The upstream aggregate error field is sampled, not a complete per-request audit stream. Repeated identical forwarding errors are deduplicated. The app does not add authentication, UDP forwarding, device identification, white lists, cloud accounts or active external probes.

## Evidence and limits

`source-check-report.json` records checks actually run in the delivery environment: core Git blob integrity, XML parsing, TOML aliases, resource references, reference colors, Python syntax and limited source scans for keys, unexpected production fixtures and literal addresses. Shell launchers and workflow YAML also underwent local syntax/structure checks.

**None of those checks compile Kotlin.** Unit, integration and instrumentation tests are present as source, but no Gradle, Android compiler, emulator, real handset or end-to-end proxy test was run for this delivery. The environment did not have an Android SDK/dependency cache or working container DNS, and GitHub writes were refused with HTTP 403. Consequently no remote commit, CI success, native screenshot comparison or APK is claimed.

The test suite covers model validation and state ownership, QR encode/decode consistency, byte-rate/window rules, configuration sharing, core parsing/counters, real local listener lifecycle and occupied ports, confirmation/editor interactions, native navigation, and fixture screenshot capture. The exact written method counts are in the source-check report, explicitly marked as not executed.

## Required acceptance before release

1. Synchronize the local source to the intended repository only after the connection has write authorization; do not force-push over existing work.
2. Run `Android checks and debug APK` against that exact commit. Resolve any dependency, compiler, lint or test failures before claiming an APK build works.
3. Run `Native UI tests and screenshots`. Review the 360dp/412dp outputs against the approved design, then test large text, TalkBack and keyboard/inset behavior. The screenshots are native test fixtures, not live-network proof.
4. Install the debug APK on a real phone. From a different device on a trusted LAN, verify HTTP, HTTPS CONNECT and SOCKS5 TCP using an authorized destination. Do not use the phone itself as the client because the upstream self-loop guard intentionally rejects it.
5. Verify edit/restart interruption, both protocols off, occupied ports, losing/changing network, notification denial, service stop, process death and repeated start/stop. Confirm exported data is user-controlled.
6. Check real lock-screen/OEM power behavior and operation alongside the user's VPN configuration. These cannot be guaranteed by listener self-tests or emulators.

Release signing, a release tag and public release publication are separate, unperformed actions. The source intentionally does not contain a keystore or copied credentials.

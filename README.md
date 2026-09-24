# APS / SIGNAL

English | [简体中文](README.zh-CN.md)

A native Android HTTP / SOCKS5 proxy application implementing the approved SIGNAL design with Jetpack Compose. This is not a WebView, an HTML wrapper, or a VPN client.

**Delivery status: source implementation, pending Android build and device verification. No successful CI run or installable APK is claimed in this delivery.** The initial write to `NingSo/APS` was denied by the connected GitHub integration (HTTP 403); this source bundle is the local handoff, not evidence of a successful push.

## Interface and behavior

The three primary destinations are Overview, Connect and Activity. Settings and local Diagnostics are secondary screens. The interface uses the original near-black/lime SIGNAL colors, a Canvas signal orbit, monospace network values, safe system insets and native bottom sheets.

- Overview controls the actual foreground service and distinguishes stopped, starting, running, stopping and failed states. The orbit does not simulate connection progress.
- Connect provides real interface addresses, protocol/port configuration, clipboard actions, a standards-based text QR code and user-triggered Android sharing. Scanning the QR does not automatically change client proxy settings.
- Activity samples real core counters each second, retains at most 60 chart samples and 200 structured session log entries, and supports local filtering and user-authorized export through the system document picker.
- Settings preserves protocol/port preferences separately from service activation. Opening the app does not automatically start a proxy. Background guidance reads actual system settings again when the activity resumes.
- Diagnostics distinguishes local listener verification from client reachability and outbound connectivity. It does not send unsolicited external probes.

Stopping explicitly clears the in-memory session, not protocol preferences. Reconfiguring listeners rebuilds the whole service and interrupts existing connections; the editor explains this before saving. A rejected configuration request rolls preferences back. Startup failures remain visible for diagnosis until the next start or process termination. Forwarding warnings do not turn the whole service into a failed state.

## Security and privacy

HTTP defaults to 8080; SOCKS5 defaults to 1080. The server listens on all local interfaces without authentication. Use only on a trusted LAN and never forward its ports to the public internet. HTTP supports HTTPS `CONNECT`; SOCKS5 supports TCP `CONNECT` only, not UDP or BIND. HTTPS tunneling does not mean all proxy traffic is encrypted.

The app does not create an Android `VpnService`, hotspot or device inventory. Outbound connections follow the platform's routing behavior; another VPN's application exclusions can affect the result. Connection counts are not device counts. There are no accounts, advertisements, telemetry or automatic uploads. Exported logs can contain network details and remain in the user-selected destination after a session stops.

## Source and build

`proxycore` contains 15 unchanged upstream Kotlin sources from `hect0x7/android-proxy-server`, pinned to `a785282cf172112590e992165090b4729d5f64dc`. `upstream-lock.json` records each Git blob hash. The new application namespace is `com.ningso.aps`; the debug application ID is `com.ningso.aps.debug`.

The declared Android baseline is API 26 minimum / API 36 target and compile SDK. Build-tool versions are pinned in `gradle/libs.versions.toml` and the wrapper properties, retaining the upstream AGP/Kotlin/Gradle versions. Dependency resolution has not been exercised in this environment.

For an explicitly requested local build, install JDK 21, Android SDK platform 36/build-tools 36.0.0 and Python 3.11+. Set `ANDROID_HOME`, or configure `sdk.dir` locally without committing `local.properties`.

```sh
python3 scripts/bootstrap_gradle.py
./gradlew :proxycore:testDebugUnitTest :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

The small wrapper JAR is intentionally not bundled. The bootstrap fetches it from the pinned upstream commit and verifies its Git blob ID before execution. It fails closed on a mismatch. Run the bootstrap once before importing into Android Studio. Gradle then needs network access for its distribution and dependencies; no SDK, compiler or Maven cache is included.

On Windows, run `python scripts/bootstrap_gradle.py`, then `gradlew.bat` with the same tasks. `JAVA_HOME` must point to JDK 21. The launchers are minimal and use `gradle.properties` for JVM settings.

A successful debug build is expected to produce `app/build/outputs/apk/debug/app-debug.apk`. Release signing and automatic releases are intentionally not configured. Debug signing is not a production signing strategy and CI-generated debug APKs may not be mutually upgrade-compatible.

## CI and review

`.github/workflows/android.yml` runs source checks, unit tests, lint and a debug build on pushes to `main`, pull requests, or manual dispatch. It uploads the APK only after a successful build; no signing secrets are required.

`.github/workflows/native-ui.yml` is manually dispatched. It runs instrumentation tests at 360dp and 412dp widths on an API 36 emulator and collects native component screenshots. Screenshots use clearly labeled test fixtures and documentation-only addresses, never production defaults. Capture success is not an automatic pixel-fidelity approval.

```sh
python3 scripts/check_source.py
```

This last command is offline source/configuration validation only, not Kotlin compilation or test execution. Read [verification and implementation notes](docs/VERIFICATION.md) before treating the app as validated.

## License

Apache License 2.0. Original copyright 2026 hect0x7 and upstream NOTICE are retained. ZXing and the other listed dependencies retain their respective licenses. No fonts, credentials, private network captures or signing keys are distributed.

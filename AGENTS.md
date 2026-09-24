# APS repository instructions

- Target repository: NingSo/APS; default branch: main. Preserve existing remote work; never force-push without specific authorization.
- Product: native Compose HTTP/SOCKS5 TCP proxy server, not a VPN client or HTML shell.
- Preserve the 15 upstream core sources and their provenance unless a core change is explicitly requested. Apache LICENSE and upstream NOTICE must remain.
- No accounts, advertising, telemetry, automatic uploads, authentication, hotspot management or simulated production traffic.
- Use the existing model/ViewModel/service separation. Preferences are not actual runtime state. Local listener success is not external reachability.
- Use the checked-in CI workflows for build/test verification. Do not run local Gradle/build/dependency installation unless a local build/test is explicitly requested.
- Do not claim compiler, emulator, device, screenshot-fidelity or proxy-transfer verification without execution evidence.
- Before commit/push, run the offline source check and inspect the diff for keys, private network values, local paths and real-user captures. Never commit signing material or fonts.
- Keep user-facing Markdown in English and equivalent Simplified Chinese files. Diagnostics and sharing must be honest about protocol limitations.
- No release, release signing, tag publication or destructive Git operations are authorized by ordinary source synchronization.

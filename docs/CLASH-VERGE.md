# Clash Verge setup & troubleshooting

[Back to the short use case](../README.md#clash-verge) · [简体中文](CLASH-VERGE.zh-CN.md)

## Connect the phone and computer

APS runs on the phone; Clash Verge sends selected computer TCP requests to it. Both devices must be reachable on a trusted network, such as the same Wi-Fi. Hotspot access depends on the actual devices and policies. Connect the phone VPN first when needed, then return to APS and start it. Keep APS foregrounded on iPhone/iPad.

Save the [complete YAML example](examples/APS-Clash-Verge.yaml), replace both occurrences of `192.0.2.10` with the address displayed in APS and check the ports. The example uses Clash Verge Rev / Mihomo syntax. Import and activate it as a separate local profile; do not overwrite an existing subscription. Select the enabled `APS-SOCKS5` or `APS-HTTP` node in the `APS` group, then enable system proxy. Leave computer TUN off for the first browser test to reduce troubleshooting variables.

| Setting | Meaning |
| --- | --- |
| Phone `1080` / `8080` | Default APS SOCKS5 / HTTP ports; use the phone's actual settings. |
| Computer `7897` | Clash's local mixed proxy port; UI settings or overrides may change it. |
| `192.0.2.10` | Documentation address: replace it. Do not use `0.0.0.0` or the computer's `127.0.0.1` as the phone address. |
| `allow-lan: false` | Prevents other devices using the computer's Clash inbound; it does not block connecting to the phone. |
| `MATCH,APS` | Sends proxyable TCP requests entering Clash to APS, not every packet from the computer. |
| `udp: false` / `tls: false` | APS has no SOCKS5 UDP. The HTTP endpoint has no extra TLS layer, but HTTPS destinations still work through CONNECT. |

For an existing profile, merge nodes and the group and direct the intended rules to `APS`; do not duplicate top-level YAML keys. Existing `DIRECT` rules may still use the computer's direct connection. APS has no proxy username/password. QR codes carry configuration text rather than automatically modifying system settings.

Without Clash, applications that follow the system HTTP proxy can use the phone address and APS HTTP port directly. On macOS, both HTTP and HTTPS proxy entries can point to the same APS HTTP port; avoid letting Clash overwrite those system settings.

## Conditions for using the phone VPN

The maintainer reports successful use in company-permitted environments including aTrust. This is not official vendor certification or a guarantee for every version, deployment or device.

| Check | What to verify |
| --- | --- |
| Organization approval | Forwarding and destination access must be authorized. A proxy does not replace login, device certificates or compliance checks. |
| VPN app coverage | Android per-app VPN must include the actual app: stable `com.ningso.aps`, or older debug `com.ningso.aps.debug`. A work-profile VPN may not cover personal-profile apps. |
| Two routing decisions | Computer Clash selects APS; the phone VPN then selects its tunnel for APS's destination. The phone browser may follow different rules. |
| LAN reachability | VPN LAN blocking, OS lockdown, Wi-Fi isolation or hotspot policies can prevent access. Allow necessary traffic as directed by the administrator, not by indiscriminately disabling protections. |
| DNS and protocols | Internal names need the correct DNS path. `socks5h` can delegate destination resolution to the phone; Clash DNS still depends on configuration. APS is TCP-only; TUN cannot add UDP support. |
| Disconnects and background | APS has no independent VPN kill switch; new connections may use ordinary routes after VPN disconnection. iOS backgrounding/locking stops APS; restart it manually on return. |

These VPN conditions apply to both HTTP and SOCKS5. Using the phone's network does not necessarily use cellular data; the phone's routing determines the actual exit.

## Verify in two stages

Test directly through the phone, then through computer Clash. Replace the example phone address and use the effective local port. Windows PowerShell users can use `curl.exe`.

```sh
# Direct to phone HTTP, with an HTTPS destination
curl --noproxy "" --proxy http://192.0.2.10:8080 --connect-timeout 10 --max-time 20 https://example.com

# Direct to phone SOCKS5, with destination resolution on the phone
curl --noproxy "" --proxy socks5h://192.0.2.10:1080 --connect-timeout 10 --max-time 20 https://example.com

# Through computer Clash and its selected APS outbound
curl --noproxy "" --proxy http://127.0.0.1:7897 --connect-timeout 10 --max-time 20 https://example.com
```

For an intranet, verify an authorized real business destination covered by the phone VPN's routes. A public destination may intentionally go direct and is not a sufficient intranet-forwarding test. Inspect the computer Clash outbound, APS counters and destination-routing logs available from the phone VPN. Local listener success does not prove remote reachability.

For public-exit checks, deliberately contact your own service or third-party [ipify](https://www.ipify.org/). One result does not establish routing for every destination, DNS or UDP; comparing phone and computer browser IPs alone is insufficient.

References: [Mihomo SOCKS5](https://wiki.metacubex.one/config/proxies/socks/) · [HTTP](https://wiki.metacubex.one/config/proxies/http/) · [rules](https://wiki.metacubex.one/config/rules/) · [Clash Verge local profiles](https://www.clashverge.dev/guide/profile.html) · [system proxy and TUN](https://www.clashverge.dev/guide/quickstart.html) · [Android per-app VPN](https://developer.android.com/develop/connectivity/vpn#per-app) · [curl options](https://curl.se/docs/manpage.html#--proxy)

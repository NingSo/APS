# Clash Verge 配置与排障

[返回简明使用场景](../README.zh-CN.md#clash-verge) · [English](CLASH-VERGE.md)

## 手机与电脑接入

手机运行 APS，电脑通过 Clash Verge 将需要代理的 TCP 请求交给手机。手机与电脑需在可信网络中互通，例如同一 Wi-Fi；热点接入以实际设备和网络策略为准。需要手机 VPN 时先连接 VPN，再返回 APS 启动；iPhone / iPad 使用期间保持 APS 前台。

保存 [完整 YAML 示例](examples/APS-Clash-Verge.yaml)，把两处 `192.0.2.10` 改为手机 APS 显示的地址，并确认端口。示例使用 Clash Verge Rev / Mihomo 格式，将它作为独立本地配置导入并启用，不要整段覆盖已有订阅。随后在 `APS` 代理组选择手机已开启的 `APS-SOCKS5` 或 `APS-HTTP`，开启系统代理。首次浏览器测试先关闭电脑 TUN，减少排障变量。

| 项目 | 说明 |
| --- | --- |
| 手机 `1080` / `8080` | APS 的 SOCKS5 / HTTP 默认端口，以手机实际设置为准。 |
| 电脑 `7897` | Clash 本地混合代理端口，可能被界面设置或覆写改变。 |
| `192.0.2.10` | 文档示例地址，必须替换；不要把 `0.0.0.0` 或电脑的 `127.0.0.1` 填成手机地址。 |
| `allow-lan: false` | 不向其他设备开放电脑的 Clash 入站，不影响电脑连接手机。 |
| `MATCH,APS` | 将进入 Clash 的可代理 TCP 请求交给 APS，不代表电脑所有流量被接管。 |
| `udp: false` / `tls: false` | APS 不支持 SOCKS5 UDP；HTTP 入口不额外套 TLS，但仍能通过 CONNECT 访问 HTTPS。 |

接入已有配置时，合并节点与代理组，让目标规则指向 `APS`，不要重复添加顶层 YAML 字段。已有 `DIRECT` 规则仍可能从电脑直连。APS 无代理用户名和密码；二维码提供配置文本，不会自动修改系统设置。

不使用 Clash 时，遵循系统 HTTP 代理的应用可直接配置手机地址和 APS 的 HTTP 端口。macOS 的 HTTP 与 HTTPS 代理项可指向同一个 APS HTTP 端口；避免 Clash 的系统代理设置将其覆盖。

## 使用手机 VPN 的条件

维护者报告已在公司允许的 aTrust 等环境实测此方案；这不是厂商官方认证，也不保证所有版本、部署和设备都兼容。

| 检查点 | 需要确认 |
| --- | --- |
| 公司许可 | 转发和目标访问均在授权范围内；代理不替代登录、设备证书或合规检查。 |
| VPN 覆盖 APS | Android 分应用 VPN 必须包含实际应用：正式包 `com.ningso.aps`，旧测试包 `com.ningso.aps.debug`。工作资料 VPN 不一定覆盖个人资料应用。 |
| 两层分流 | 电脑 Clash 先选中 APS；手机 VPN 再将 APS 的目标连接送入隧道。手机浏览器能访问，不代表 APS 使用相同策略。 |
| 局域网可达 | VPN 的局域网阻断、系统锁定、Wi-Fi 客户端隔离或热点限制可能阻止电脑连接手机。按管理员要求允许必要通信，不要一概关闭防护。 |
| DNS 与协议 | 内网域名要能经正确 DNS 解析。`socks5h` 可让手机解析目标域名，Clash 的 DNS 路径仍取决于配置。APS 仅支持 TCP，TUN 不会补齐 UDP。 |
| 断线与后台 | APS 无独立 VPN 断线阻断，VPN 断开后的新连接可能回落到普通网络。iOS 进入后台／锁屏会停止 APS，返回后手动启动。 |

HTTP 和 SOCKS5 都遵循上述 VPN 条件。“借用手机网络”不一定使用蜂窝流量；实际出口由手机路由选择。

## 分两步验证

先直接连接手机，再经过电脑 Clash。替换示例手机地址及实际本地端口；Windows PowerShell 可使用 `curl.exe`。

```sh
# 直接连接手机 HTTP，访问 HTTPS
curl --noproxy "" --proxy http://192.0.2.10:8080 --connect-timeout 10 --max-time 20 https://example.com

# 直接连接手机 SOCKS5，由手机解析域名
curl --noproxy "" --proxy socks5h://192.0.2.10:1080 --connect-timeout 10 --max-time 20 https://example.com

# 经过电脑 Clash，再由其选中的 APS 节点转发
curl --noproxy "" --proxy http://127.0.0.1:7897 --connect-timeout 10 --max-time 20 https://example.com
```

企业内网应使用获授权、且被手机 VPN 路由覆盖的实际业务地址验证。普通公网目标可能按规则直连，不能据此判断内网转发失败。结合电脑 Clash 的命中节点、APS 计数和手机 VPN 提供的目标路由日志判断；本地监听成功不等于远端目标可达。

需要公网出口检查时，可主动访问自有查询服务或第三方 [ipify](https://www.ipify.org/)。单次结果不证明其他目标、DNS 或 UDP 都经 VPN，也不能只比较手机与电脑浏览器的 IP。

参考：[Mihomo SOCKS5](https://wiki.metacubex.one/config/proxies/socks/) · [HTTP](https://wiki.metacubex.one/config/proxies/http/) · [规则](https://wiki.metacubex.one/config/rules/) · [Clash Verge 本地配置](https://www.clashverge.dev/guide/profile.html) · [系统代理与 TUN](https://www.clashverge.dev/guide/quickstart.html) · [Android 分应用 VPN](https://developer.android.com/develop/connectivity/vpn#per-app) · [curl 参数](https://curl.se/docs/manpage.html#--proxy)

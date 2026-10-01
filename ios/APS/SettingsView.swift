import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:17) {
                PageHeading(eyebrow:"FINE-TUNE YOUR SIGNAL",title:"少一点干扰。",subtitle:"只保留与你的连接有关的设置。")
                Eyebrow(text:"PROTOCOLS / 代理协议")
                SignalCard {
                    ForEach(ProxyKind.allCases) { kind in
                        SettingsRow(title:kind.rawValue,subtitle:":\(store.preferences.port(kind)) · \(store.preferences.enabled(kind) ? "已选用" : "已关闭")",glyph:.tune) { store.sheet = .port(kind) }
                        if kind == .http { SignalDivider() }
                    }
                }
                Eyebrow(text:"STAY AVAILABLE / 前台运行")
                SignalCard {
                    Toggle(isOn:Binding(get:{ store.preferences.keepAwake },set:store.setKeepAwake)) {
                        VStack(alignment:.leading,spacing:5) {
                            Text("运行时保持屏幕常亮").signalFont(14)
                            Text("仅在应用前台且代理运行时生效").signalFont(11).foregroundColor(Signal.secondary)
                        }
                    }.tint(Signal.accent).frame(minHeight:56)
                    SignalDivider()
                    SettingsRow(title:"后台与锁屏限制",subtitle:"进入后台时主动停止，返回后手动启动",glyph:.power) { store.sheet = .information(.background) }
                    SignalDivider()
                    SettingsRow(title:"本地网络权限",subtitle:"在系统应用设置中查看；不伪造授权状态",glyph:.info) { openSettings() }
                }
                Eyebrow(text:"NETWORK / 网络")
                SignalCard {
                    SettingsRow(title:"出站路由",subtitle:"遵循 iOS 当前网络路由",glyph:.globe) { store.sheet = .information(.route) }
                    SignalDivider()
                    SettingsRow(title:"连接诊断",subtitle:"逐层检查，不把监听成功当作外网连通",glyph:.activity) { store.navigate(.diagnostics) }
                }
                Eyebrow(text:"APPEARANCE / 显示")
                SignalCard {
                    Toggle(isOn:Binding(get:{ store.preferences.reduceMotion },set:store.setReduceMotion)) {
                        VStack(alignment:.leading,spacing:5) {
                            Text("减少动态效果").signalFont(14)
                            Text("停止信号轨道；同时尊重系统减少动态效果").signalFont(11).foregroundColor(Signal.secondary)
                        }
                    }.tint(Signal.accent).frame(minHeight:56).accessibilityIdentifier("reduce-motion")
                    SignalDivider()
                    SettingsRow(title:"SIGNAL / 夜航",subtitle:"黑曜石 × 荧光绿 · 动态字体",glyph:.info) { store.sheet = .information(.theme) }
                }
                SignalCard {
                    Text("你的连接，留在你的设备。").signalFont(17)
                    Text("没有账号、广告、遥测或云端历史。偏好保存在本机，会话数据仅驻留内存。复制、分享、导出由你主动发起。").signalFont(12).foregroundColor(Signal.secondary).lineSpacing(4)
                    SettingsRow(title:"APS / SIGNAL",subtitle:"开放源代码 · Apache License 2.0",glyph:.info) { store.sheet = .information(.about) }
                }
            }.screenPadding()
        }.accessibilityIdentifier("screen-settings")
    }
    private func openSettings() {
        guard let url = URL(string:UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
struct SettingsRow: View {
    let title:String
    let subtitle:String
    var glyph:Glyph = .info
    let action:()->Void
    var body:some View {
        Button(action:action) {
            HStack(spacing:12) {
                SignalIcon(glyph:glyph,color:Signal.accent).frame(width:21,height:21)
                VStack(alignment:.leading,spacing:5) {
                    Text(title).signalFont(14)
                    Text(subtitle).signalFont(11).foregroundColor(Signal.secondary).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:.infinity,alignment:.leading)
                SignalIcon(glyph:.arrow,color:Signal.secondary).frame(width:18,height:18)
            }.frame(minHeight:62).contentShape(Rectangle())
        }.buttonStyle(PressFeedback())
    }
}
struct DiagnosticsView: View {
    @ObservedObject var store:AppStore
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                PageHeading(eyebrow:"FOLLOW THE CONNECTION",title:"找到连接的断点。",subtitle:"先检查手机本地，再验证客户端与目标。")
                SecondaryAction(title:"重新检查本机状态",glyph:.activity) {
                    store.refreshNetwork(); store.note("已刷新本机地址；客户端和外网仍需另行验证")
                }
                step("01","局域网地址",store.host == nil ? "未发现" : "已发现",
                     store.host.map { "\($0)\n这是本机地址，不保证其他设备可达。" } ?? "确认手机接入可信 Wi-Fi，或手动开启个人热点；避免访客网络隔离。",store.host == nil ? Signal.warning : Signal.accent)
                step("02","本地监听",store.session.phase == .running ? "自检通过" : store.session.phase == .failed ? "启动失败" : "尚未监听",
                     store.session.phase == .running ? "已选用的监听器完成回环连接及随机标记回显校验。这不是外网测试，也不证明局域网权限已获准。" : store.session.error ?? "在概览页选用协议并确认可信网络后启动。",store.session.phase == .running ? Signal.accent : Signal.warning)
                step("03","客户端 → 手机",store.session.active > 0 ? "有入站连接" : "待验证",
                     store.session.active > 0 ? "观察到 \(store.session.active) 条活动 TCP 连接；连接条数不等于设备数。" : "在另一台设备填写正确协议、地址、端口。检查本地网络权限、路由器隔离及防火墙。",Signal.secondary)
                step("04","手机 → 目标","未主动测试","此页面不访问任何外部测试站点。系统 VPN、分流与网络策略可能影响实际出站路径。",Signal.secondary)
                step("05","后台持续运行","不支持常驻","普通 iOS 应用会被系统挂起。本版本在进入后台时主动停止；屏幕常亮不等于后台权限。",Signal.warning)
                SecondaryAction(title:"查看前台运行说明",glyph:.power) { store.sheet = .information(.background) }
                SecondaryAction(title:"获取客户端测试命令",glyph:.terminal) { store.clientChoice = 4; store.navigate(.connect) }
                Text("HTTP / HTTPS CONNECT 与 SOCKS5 TCP CONNECT 不可混用端口。没有用户名密码、UDP ASSOCIATE 或 BIND。").signalFont(11).foregroundColor(Signal.secondary).lineSpacing(4)
            }.screenPadding()
        }.accessibilityIdentifier("screen-diagnostics")
    }
    private func step(_ number:String,_ title:String,_ status:String,_ detail:String,_ color:Color)->some View {
        SignalCard {
            HStack(spacing:12) {
                Text(number).signalFont(15,mono:true).foregroundColor(Signal.accent)
                Text(title).signalFont(15); Spacer(minLength:4)
                Text(status).signalFont(10).foregroundColor(color)
            }
            Text(detail).signalFont(12).foregroundColor(Signal.secondary).lineSpacing(4)
        }
    }
}

import SwiftUI

struct OverviewView: View {
    @ObservedObject var store: AppStore
    let reduced: Bool
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                VStack(alignment:.leading,spacing:7) {
                    HStack(spacing:10) { Text(store.session.phase.title).signalFont(29); Spacer(minLength:0); StatePill(phase:store.session.phase) }
                    Text("手机变代理。让局域网里的设备，共享连接。").signalFont(12).foregroundColor(Signal.secondary)
                }
                orbitArea
                if store.session.phase == .failed {
                    SignalCard {
                        Text(store.session.error ?? "请查看诊断和会话日志").signalFont(12).foregroundColor(Signal.error)
                        SecondaryAction(title:"修改 HTTP 端口并重试",glyph:.tune) { store.sheet = .port(.http) }
                        SecondaryAction(title:"查看诊断",glyph:.activity) { store.navigate(.diagnostics) }
                    }
                }
                SignalCard {
                    HStack(alignment:.top,spacing:15) {
                        VStack { Metric(title:"↓ 接收速率",bytes:store.session.receiveRate,rate:true); TrafficChart(samples:store.session.samples,compact:true).frame(height:17) }
                        Rectangle().fill(Signal.border).frame(width:1,height:60)
                        VStack { Metric(title:"↑ 发送速率",bytes:store.session.sendRate,rate:true); TrafficChart(samples:store.session.samples,compact:true,sentOnly:true).frame(height:17) }
                    }
                }
                if let host = store.host { addressCard(host) }
                else {
                    SignalCard {
                        Text("先找到局域网").signalFont(20)
                        Text("让客户端与手机接入同一可信网络。没有可达地址时，不生成连接二维码。").signalFont(12).foregroundColor(Signal.secondary)
                        SecondaryAction(title:"检查连接",glyph:.link) { store.navigate(.diagnostics) }
                    }
                }
                HStack { Text("代理协议").signalFont(12); Spacer(); Eyebrow(text:"\(store.session.active) ACTIVE CONNECTIONS") }
                HStack(spacing:10) { protocolCard(.http); protocolCard(.socks5) }
                Button { store.sheet = .information(.risk) } label: {
                    HStack(spacing:7) {
                        SignalIcon(glyph:.alert,color:Signal.warning).frame(width:16,height:16)
                        Text("无密码鉴权，仅在可信局域网开启。了解风险").signalFont(10).foregroundColor(Signal.warning)
                    }.frame(minHeight:48)
                }.buttonStyle(PressFeedback())
            }.screenPadding()
        }.accessibilityIdentifier("screen-overview")
    }
    private var orbitArea: some View {
        ZStack {
            SignalOrbit(phase:store.session.phase,animate:!reduced && store.foreground,action:store.power).offset(y:-7)
            HStack {
                VStack(alignment:.leading,spacing:7) {
                    Eyebrow(text:"LOCAL",color:Signal.muted)
                    Text("LAN / IPv4").signalFont(10,mono:true)
                    SignalDivider().frame(width:44)
                    Eyebrow(text:"TCP ONLY",color:Signal.muted)
                }
                Spacer()
                VStack(alignment:.trailing,spacing:7) {
                    Eyebrow(text:"SESSION",color:Signal.muted)
                    Text(sessionDuration(store.session.elapsed)).signalFont(10,mono:true).monospacedDigit()
                    SignalDivider().frame(width:44)
                    Eyebrow(text:"NO CLOUD",color:Signal.muted)
                }
            }.allowsHitTesting(false)
            VStack { Spacer(); HStack(spacing:5) {
                SignalIcon(glyph:store.session.phase == .running ? .check : .info,color:Signal.secondary).frame(width:13,height:13)
                Text(statusText).signalFont(10).foregroundColor(store.session.phase == .failed ? Signal.error : Signal.secondary)
            } }
        }.frame(height:215)
    }
    private var statusText: String {
        switch store.session.phase {
        case .running: return "本地监听自检通过 · 请保持前台"
        case .starting: return "绑定端口 · 校验本地监听"
        case .stopping: return "正在关闭活动连接"
        case .failed: return "启动失败，请检查端口或系统权限"
        case .stopped: return "iOS 前台代理 · 后台或锁屏时停止"
        }
    }
    private func addressCard(_ host:String) -> some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Eyebrow(text:"YOUR LOCAL ADDRESS",color:Signal.onAccent.opacity(0.7)); Spacer(); Text("局域网 · IPv4").signalFont(9) }
            HStack {
                Text(host).signalFont(24,mono:true).minimumScaleFactor(0.7).lineLimit(1).accessibilityIdentifier("local-address")
                Spacer(minLength:0)
                IconControl(glyph:.copy,label:"复制地址",color:Signal.onAccent) { store.copy(host) }
            }
            Rectangle().fill(Signal.onAccent.opacity(0.2)).frame(height:1)
            Button { store.navigate(.connect) } label: {
                HStack {
                    Text("客户端填写此地址，不是 0.0.0.0").signalFont(10)
                    Spacer(minLength:4); Text("连接设备").signalFont(11)
                    SignalIcon(glyph:.arrow,color:Signal.onAccent).frame(width:17,height:17)
                }.frame(minHeight:48)
            }.buttonStyle(PressFeedback())
        }.padding(.leading,18).padding(.trailing,12).padding(.top,18).padding(.bottom,8)
            .foregroundColor(Signal.onAccent).background(Signal.accent,in:RoundedRectangle(cornerRadius:20))
    }
    private func protocolCard(_ kind:ProxyKind) -> some View {
        let active = store.session.listening(kind,preferences:store.preferences)
        return Button { store.sheet = .port(kind) } label: {
            SignalCard {
                HStack {
                    Text(kind.rawValue).signalFont(13); Spacer(minLength:3)
                    Text(active ? "● 运行中" : store.preferences.enabled(kind) ? "已选用" : "已关闭")
                        .signalFont(9).foregroundColor(active ? Signal.accent : Signal.secondary)
                }
                HStack {
                    // Endpoints are identifiers, not locale-formatted quantities.
                    Text(verbatim:":\(store.preferences.port(kind))").signalFont(18,mono:true)
                    Spacer(); SignalIcon(glyph:.tune).frame(width:19,height:19)
                }
            }
        }.buttonStyle(PressFeedback()).disabled(store.session.phase.busy)
            .accessibilityIdentifier("protocol-\(kind.rawValue)")
    }
}

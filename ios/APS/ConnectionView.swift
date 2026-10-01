import SwiftUI

struct ConnectionView: View {
    @ObservedObject var store: AppStore
    private var kind: ProxyKind { store.protocolChoice }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                PageHeading(eyebrow:"MAKE THE CONNECTION",title:"下一台，连接。",subtitle:"让客户端与手机处于同一可信局域网。")
                if let host = store.host {
                    Choices(labels:ProxyKind.allCases.map { $0.rawValue + (store.session.listening($0,preferences:store.preferences) ? "  ● ON" : "  ○ OFF") },
                            selected:kind == .http ? 0 : 1) { store.protocolChoice = ProxyKind.allCases[$0] }
                    connectionPass(host)
                    if store.addresses.count > 1 {
                        Menu {
                            ForEach(store.addresses) { address in Button(address.host) { store.selectAddress(address.host) } }
                        } label: {
                            Text("多个本机地址 · 选择客户端可达地址").signalFont(12).foregroundColor(Signal.accent).frame(minHeight:48)
                        }
                    }
                    HStack(spacing:10) {
                        SecondaryAction(title:"二维码分享",glyph:.qr) { store.sheet = .share(kind) }
                        SecondaryAction(title:"连接诊断",glyph:.activity) { store.navigate(.diagnostics) }
                    }
                    if !store.preferences.enabled(kind) {
                        SecondaryAction(title:"启用 \(kind.rawValue)",glyph:.tune) { store.sheet = .port(kind) }
                    }
                    instructions(host)
                    Text("二维码只包含配置文本，不会自动设置系统代理。无身份鉴权，请勿将端口直接暴露到互联网。")
                        .signalFont(11).foregroundColor(Signal.secondary).lineSpacing(4)
                } else {
                    SignalCard {
                        SignalIcon(glyph:.link,color:Signal.warning).frame(width:24,height:24)
                        Text("接入可信局域网后再继续").signalFont(21)
                        Text("本应用不会自动创建热点。发现可达地址后，才能生成对应的连接配置。").signalFont(12).foregroundColor(Signal.secondary)
                        SecondaryAction(title:"返回概览",glyph:.back) { store.navigate(.overview) }
                    }
                }
            }.screenPadding()
        }.accessibilityIdentifier("screen-connect")
    }
    private func connectionPass(_ host:String) -> some View {
        let payload = configurationText(host:host,preferences:store.preferences,kind:kind)
        let active = store.session.listening(kind,preferences:store.preferences)
        return VStack(alignment:.leading,spacing:12) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Eyebrow(text:"CONNECTION PASS",color:Signal.onAccent.opacity(0.6))
                    Text("\(kind.rawValue) / TCP").signalFont(22,mono:true)
                }; Spacer()
                SignalIcon(glyph:kind == .http ? .globe : .terminal,color:Signal.onAccent).frame(width:24,height:24)
            }
            HStack(spacing:12) {
                VStack(alignment:.leading,spacing:6) {
                    Text("主机地址 / HOST").signalFont(10).opacity(0.65)
                    Text(host).signalFont(21,mono:true).minimumScaleFactor(0.7).lineLimit(1)
                    HStack(spacing:26) {
                        VStack(alignment:.leading) { Text("端口 / PORT").signalFont(9).opacity(0.65); Text(String(store.preferences.port(kind))).signalFont(19,mono:true) }
                        VStack(alignment:.leading) { Text("身份认证 / AUTH").signalFont(9).opacity(0.65); Text("无").signalFont(19) }
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
                Button { store.sheet = .share(kind) } label: { QRCodeView(text:payload).frame(width:70,height:70) }.accessibilityLabel("展开二维码")
            }
            Rectangle().fill(Signal.onAccent.opacity(0.25)).frame(height:1)
            HStack {
                Text(active ? "本地监听中 · 请手动配置客户端" : store.preferences.enabled(kind) ? "尚未监听 · 启动后可连接" : "此协议未选用，请先启用").signalFont(10)
                Spacer(); IconControl(glyph:.copy,label:"复制配置",color:Signal.onAccent) { store.copy(payload) }
            }
        }.padding(20).foregroundColor(Signal.onAccent).background(Signal.accent,in:RoundedRectangle(cornerRadius:22))
    }
    private func instructions(_ host:String) -> some View {
        SignalCard {
            HStack { Text("在客户端上配置").signalFont(15); Spacer(); Eyebrow(text:"3 STEPS") }
            Choices(labels:["Windows","macOS","Android","iOS","命令行"],selected:store.clientChoice,compact:true) { store.clientChoice = $0 }
            ForEach(Array(steps(host).enumerated()),id:\.offset) { index,text in
                HStack(alignment:.top,spacing:10) {
                    Text("\(index+1)").signalFont(11,mono:true).foregroundColor(Signal.accent)
                    Text(text).signalFont(12).foregroundColor(Signal.secondary).lineSpacing(4)
                }
            }
            if store.clientChoice == 4 {
                let command = clientCommand(host:host,preferences:store.preferences,kind:kind)
                VStack(alignment:.leading,spacing:8) {
                    Text(command).signalFont(11,mono:true).textSelection(.enabled)
                    Button("复制命令") { store.copy(command) }.signalFont(12).frame(minHeight:44).foregroundColor(Signal.accent)
                }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Signal.background,in:RoundedRectangle(cornerRadius:10))
            }
        }
    }
    private func steps(_ host:String) -> [String] {
        let address = "填写 \(host) 和 \(store.preferences.port(kind))，不设置用户名或密码。"
        if store.clientChoice == 4 { return ["先确认客户端可以访问手机的局域网地址。","执行下方命令；Windows PowerShell 请使用 curl.exe。","必须在另一台客户端执行；代理手机上的回环请求会被拒绝。"] }
        if kind == .socks5 && store.clientChoice != 1 { return ["系统的普通 HTTP 代理输入项不等于 SOCKS5。","使用明确支持 SOCKS5 的客户端或应用，选择 SOCKS5 协议。",address] }
        switch store.clientChoice {
        case 0: return ["打开「设置 → 网络和 Internet → 代理」。","在手动设置代理中开启「使用代理服务器」。",address]
        case 1: return ["打开「系统设置 → 网络 → 当前网络 → 详细信息 → 代理」。",kind == .http ? "选择网页代理（HTTP）；HTTPS 通过 CONNECT 转发。" : "选择 SOCKS 代理。",address]
        case 3: return ["在另一台 iPhone / iPad 打开「设置 → Wi-Fi → 当前网络」。","进入「配置代理」，选择「手动」。",address + " 并非所有应用都会遵循该设置。"]
        default: return ["打开当前 Wi-Fi 的网络详情，编辑代理设置。","选择「手动」。",address + " 并非所有应用都会遵循系统代理。"]
        }
    }
}

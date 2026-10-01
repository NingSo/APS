import SwiftUI
import UniformTypeIdentifiers

struct SheetContent:View {
    @ObservedObject var store:AppStore
    let route:SheetRoute
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:17) {
                HStack {
                    Capsule().fill(Signal.secondary.opacity(0.4)).frame(width:35,height:4).frame(maxWidth:.infinity)
                }.padding(.top,12).accessibilityHidden(true)
                HStack { Spacer(); IconControl(glyph:.close,label:"关闭弹层") { store.sheet = nil } }
                content
            }.padding(.horizontal,22).padding(.bottom,28)
        }.frame(maxWidth:.infinity,maxHeight:.infinity).background(Signal.surface).foregroundColor(Signal.text).tint(Signal.accent)
            .presentationDetents([.large]).presentationDragIndicator(.hidden).preferredColorScheme(.dark)
    }
    @ViewBuilder private var content:some View {
        switch route {
        case let .consent(host,revision): ConsentContent(store:store,host:host,revision:revision)
        case .stop:
            Eyebrow(text:"END THIS SESSION",color:Signal.warning)
            Text("结束本次连接？").signalFont(25)
            Text("\(store.session.active) 条活动连接将关闭。当前统计和日志会清空；协议偏好与端口仍保留。需要日志时，请先取消并前往活动页导出。").signalFont(13).foregroundColor(Signal.secondary).lineSpacing(5)
            PrimaryAction(title:"停止并清空会话") { store.stop() }.accessibilityIdentifier("confirm-stop")
            SecondaryAction(title:"继续运行",glyph:.back) { store.sheet = nil }
        case .port(let kind): PortContent(store:store,kind:kind)
        case .share(let kind):
            if let host = store.host { ShareContent(store:store,host:host,kind:kind) }
            else { Text("地址已失效，请返回连接页。").signalFont(16) }
        case .information(let topic): InformationContent(topic:topic)
        case .export: ExportContent(store:store)
        }
    }
}
private struct ConsentContent:View {
    @ObservedObject var store:AppStore
    let host:String
    let revision:Int
    @State private var trusted = false
    var body:some View {
        Eyebrow(text:"BEFORE YOU START",color:Signal.warning)
        Text("只在可信网络中开启。").signalFont(25)
        Text("代理没有用户名和密码。可访问手机端口的设备能够使用代理；请勿在不可信网络中开启，或将端口映射到公网。").signalFont(13).foregroundColor(Signal.secondary).lineSpacing(5)
        Text("iOS 版本需保持应用前台；进入后台或锁屏后将停止服务。").signalFont(12).foregroundColor(Signal.warning)
        Text("当前地址：\(host)").signalFont(12,mono:true)
        Toggle("我确认当前网络可信，并了解无鉴权风险。",isOn:$trusted).signalFont(13).frame(minHeight:56).tint(Signal.accent).accessibilityIdentifier("trust-network")
        PrimaryAction(title:"确认并启动",enabled:trusted && store.host == host && store.networkRevision == revision) {
            store.confirmStart(host:host,revision:revision)
        }.accessibilityIdentifier("confirm-start")
        SecondaryAction(title:"暂不开启",glyph:.back) { store.sheet = nil }
    }
}
private struct PortContent:View {
    @ObservedObject var store:AppStore
    let kind:ProxyKind
    @State private var text = ""
    @State private var enabled = true
    @FocusState private var focused:Bool
    private var error:String? { Preferences.portError(text,other:store.preferences.port(kind == .http ? .socks5 : .http)) }
    private var changed:Bool { Int(text) != store.preferences.port(kind) || enabled != store.preferences.enabled(kind) }
    var body:some View {
        VStack(alignment:.leading,spacing:17) {
            Eyebrow(text:"LISTENER CONFIGURATION")
            Text("\(kind.rawValue) 监听配置").signalFont(25)
            Text(kind == .http ? "HTTP 转发与 HTTPS CONNECT 隧道。" : "SOCKS5 TCP CONNECT；不支持 UDP 或 BIND。").signalFont(12).foregroundColor(Signal.secondary)
            Toggle("选用此协议",isOn:$enabled).signalFont(14).frame(minHeight:48).accessibilityIdentifier("protocol-enabled")
            Text("端口 / PORT").signalFont(11).foregroundColor(Signal.secondary)
            TextField("1–65535",text:$text).keyboardType(.numberPad).signalFont(32,mono:true).focused($focused)
                .padding(18).frame(minHeight:72).background(Signal.background,in:RoundedRectangle(cornerRadius:14))
                .overlay(RoundedRectangle(cornerRadius:14).stroke(error == nil ? Signal.accent.opacity(0.6) : Signal.error,lineWidth:1))
                .foregroundColor(error == nil ? Signal.accent : Signal.error).accessibilityIdentifier("port-input")
                .onChange(of:text) { if $0.count > 12 { text = String($0.prefix(12)) } }
                .toolbar { ToolbarItemGroup(placement:.keyboard) { Spacer(); Button("完成") { focused = false } } }
            Text(error ?? "范围 1–65535；两个协议必须使用不同端口").signalFont(11).foregroundColor(error == nil ? Signal.secondary : Signal.error).accessibilityIdentifier("port-validation")
            if let port = Int(text), (1...1023).contains(port) {
                Text("低位端口可能受到系统限制；格式有效不代表能够绑定。").signalFont(12).foregroundColor(Signal.warning)
            }
            if store.session.phase == .running {
                Text("保存会重建整个服务，\(store.session.active) 条连接可能中断；统计重新开始。若两个协议均关闭，则停止服务。").signalFont(12).foregroundColor(Signal.warning).lineSpacing(4)
            }
            HStack(spacing:10) {
                SecondaryAction(title:"取消",glyph:.close) { store.sheet = nil }
                PrimaryAction(title:store.session.phase == .running ? "保存并重建" : "保存配置",enabled:error == nil && changed && !store.session.phase.busy) {
                    focused = false; store.save(kind,text:text,enabled:enabled)
                }.accessibilityIdentifier("save-port")
            }
        }.onAppear { text = String(store.preferences.port(kind)); enabled = store.preferences.enabled(kind) }
    }
}
private struct ShareContent:View {
    @ObservedObject var store:AppStore
    let host:String
    let kind:ProxyKind
    private var payload:String { configurationText(host:host,preferences:store.preferences,kind:kind) }
    var body:some View {
        Eyebrow(text:"PASS THE CONNECTION")
        Text("把连接交给下一台。").signalFont(25)
        QRCodeView(text:payload).frame(width:214,height:214).frame(maxWidth:.infinity).padding(.vertical,12)
        Text("\(kind.rawValue) / \(host):\(store.preferences.port(kind))").signalFont(15,mono:true).frame(maxWidth:.infinity).textSelection(.enabled)
        Text("二维码是配置文本，需要手动填入客户端。无鉴权，仅限可信局域网；分享给谁，由你决定。").signalFont(12).foregroundColor(Signal.secondary).lineSpacing(4)
        ShareLink(item:payload) {
            Text("分享配置文本").signalFont(14,weight:.medium).frame(maxWidth:.infinity,minHeight:50)
                .foregroundColor(Signal.onAccent).background(Signal.accent,in:RoundedRectangle(cornerRadius:14))
        }.accessibilityIdentifier("system-share")
        SecondaryAction(title:"复制配置",glyph:.copy) { store.copy(payload) }
    }
}
private struct InformationContent:View {
    let topic:InfoTopic
    var body:some View {
        Eyebrow(text:"APS / SIGNAL")
        Text(title).signalFont(25)
        Text(detail).signalFont(13).foregroundColor(Signal.secondary).lineSpacing(6).textSelection(.enabled)
        if topic == .about {
            if let path = Bundle.main.url(forResource:"LICENSE",withExtension:nil), let license = try? String(contentsOf:path,encoding:.utf8) {
                Text(license).signalFont(10,mono:true).foregroundColor(Signal.secondary)
            }
        }
    }
    private var title:String {
        switch topic { case .risk: return "连接有边界。"; case .background: return "保持前台，保持可用。"; case .route: return "遵循系统路由。"; case .theme: return "SIGNAL / 夜航"; case .about: return "APS · 开放源代码" }
    }
    private var detail:String {
        switch topic {
        case .risk: return "这是局域网 HTTP / SOCKS5 代理，不是 VPN 客户端。没有用户名密码，不要映射到公网。HTTPS CONNECT 保留客户端到目标的 TLS，不代表所有 HTTP 或 SOCKS 流量已加密。\n\nSOCKS5 仅支持 TCP CONNECT；不支持 UDP、BIND、限速、白名单或设备身份识别。"
        case .background: return "普通 iOS App 不能无限期在后台监听端口。本版本在进入后台时主动关闭会话，返回后由你重新启动。不会使用静音音频、定位或伪装后台任务保活。\n\n可选的屏幕常亮只在前台运行时生效，并会增加耗电；不能阻止手动锁屏或系统终止。"
        case .route: return "出站连接由 iOS 选择路由。本应用不建立 VPN 接口，不占用 VPN 槽位，也不强制绑定某个出口。其他 VPN、分流配置、Wi-Fi 或蜂窝策略可能改变实际路径，需要在目标设备验证。"
        case .theme: return "黑曜石 #090D0B × 荧光绿 #C1F76B。\n\n信号环采用原生 Canvas；外圈 20 秒一圈，内圈反向 38 秒一圈。关闭动态效果或离开前台时暂停动画。网络成功状态来自真实本地监听校验，而不是动画计时。"
        case .about: return "本 iOS 实现重新编写，使用 SwiftUI、Network.framework 和 Core Image，不复用已删除的旧 iOS 源码。\n\n产品视觉与行为基于已验收 Android SIGNAL 版本；上游 Android Proxy Server：Copyright 2026 hect0x7。遵循仓库 Apache License 2.0。没有账号、广告、遥测和自动上传。"
        }
    }
}
struct SessionDocument:FileDocument {
    static var readableContentTypes:[UTType] { [.plainText] }
    var text:String
    init(text:String) { self.text = text }
    init(configuration:ReadConfiguration) throws { text = String(decoding:configuration.file.regularFileContents ?? Data(),as:UTF8.self) }
    func fileWrapper(configuration:WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:Data(text.utf8)) }
}
private struct ExportContent:View {
    @ObservedObject var store:AppStore
    @State private var document = SessionDocument(text:"")
    @State private var exporting = false
    var body:some View {
        Eyebrow(text:"EXPORT THIS SESSION")
        Text("把日志留给自己。").signalFont(25)
        Text("日志可能包含网络错误和地址信息。请检查内容，并只分享到你信任的位置。已经导出的文件不会随停止会话自动删除。").signalFont(13).foregroundColor(Signal.secondary).lineSpacing(5)
        PrimaryAction(title:"确认并选择保存位置",enabled:!store.session.events.isEmpty) {
            document = SessionDocument(text:store.exportText()); exporting = true
        }.fileExporter(isPresented:$exporting,document:document,contentType:.plainText,defaultFilename:"aps-session") { result in
            switch result {
            case .success: store.note("日志已导出")
            case .failure: store.note("未完成导出")
            }
        }
    }
}

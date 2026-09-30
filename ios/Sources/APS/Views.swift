import CoreImage.CIFilterBuiltins
import SwiftUI

private enum Signal {
    static let background = Color(red: 0.035, green: 0.051, blue: 0.043)
    static let surface = Color(red: 0.078, green: 0.102, blue: 0.086)
    static let raised = Color(red: 0.11, green: 0.141, blue: 0.118)
    static let border = Color(red: 0.169, green: 0.212, blue: 0.18)
    static let text = Color(red: 0.937, green: 0.961, blue: 0.929)
    static let secondary = Color(red: 0.627, green: 0.686, blue: 0.635)
    static let accent = Color(red: 0.757, green: 0.969, blue: 0.42)
    static let mint = Color(red: 0.478, green: 0.855, blue: 0.812)
    static let warning = Color(red: 0.929, green: 0.741, blue: 0.475)
    static let error = Color(red: 1.0, green: 0.592, blue: 0.541)
}

struct RootView: View {
    @ObservedObject var model: APSViewModel
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderView(title: tab == 3 ? "偏好设置" : "APS", showsBack: tab == 3) {
                    tab = 0
                }
                Group {
                    switch tab {
                    case 0: OverviewView(model: model)
                    case 1: ConnectView(model: model)
                    case 2: ActivityView(model: model)
                    default: SettingsView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                BottomBar(tab: $tab)
            }
            .background(Signal.background.ignoresSafeArea())
            .foregroundStyle(Signal.text)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showRisk) { RiskSheet() }
        .sheet(item: $model.showPortEditor) { kind in PortEditor(model: model, kind: kind) }
    }
}

private struct HeaderView: View {
    let title: String
    let showsBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Signal.accent.opacity(0.35), lineWidth: 1)
                    .frame(width: 42, height: 42)
                    .overlay(Text("A").font(.system(size: 25, weight: .light, design: .rounded)).foregroundStyle(Signal.accent))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 19, weight: .medium))
                Text("IOS PROXY SERVER").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.6).foregroundStyle(Signal.secondary)
            }
            Spacer()
            Button(action: { }) { Image(systemName: "gearshape").font(.system(size: 23, weight: .light)) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

private struct BottomBar: View {
    @Binding var tab: Int
    private let items = [("slider.horizontal.3", "概览"), ("link", "连接"), ("waveform.path.ecg", "活动"), ("gearshape", "设置")]

    var body: some View {
        HStack {
                ForEach(items.indices, id: \.self) { index in
                Button { tab = index } label: {
                    VStack(spacing: 5) {
                        Image(systemName: items[index].0).font(.system(size: 21, weight: .light))
                        Text(items[index].1).font(.system(size: 10))
                    }
                    .foregroundStyle(tab == index ? Signal.accent : Signal.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(tab == index ? Signal.accent.opacity(0.08) : .clear, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .background(Signal.background.opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(Signal.border).frame(height: 1) }
    }
}

private struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !eyebrow.isEmpty { Text(eyebrow).font(.system(size: 9, design: .monospaced)).tracking(1.6).foregroundStyle(Signal.secondary) }
            Text(title).font(.system(size: 30, weight: .medium, design: .rounded))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Signal.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SignalCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Signal.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Signal.border, lineWidth: 1))
    }
}

private struct StatePill: View {
    let phase: SessionPhase
    var body: some View {
        Text(phase.label).font(.system(size: 9, design: .monospaced)).tracking(1)
            .foregroundStyle(phase == .running ? Signal.accent : phase == .failed ? Signal.error : Signal.secondary)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background((phase == .running ? Signal.accent : Signal.secondary).opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct OverviewView: View {
    @ObservedObject var model: APSViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: "", title: model.runtime.running ? "连接，就绪。" : "让连接，发生。", subtitle: "手机变代理。让局域网里的设备，共享连接。")
                    StatePill(phase: model.runtime.phase)
                }
                OrbitView(phase: model.runtime.phase, reducedMotion: model.settings.reducedMotion) {
                    if model.runtime.running { model.stop() } else { model.start() }
                }
                SignalCard {
                    HStack {
                        Metric(title: "↓  接收速率", value: "0", unit: "B/s")
                        Divider().overlay(Signal.border)
                        Metric(title: "↑  发送速率", value: "0", unit: "B/s")
                    }
                }
                if let host = model.host {
                    AddressCard(host: host)
                } else {
                    SignalCard { Text("先找到局域网。").font(.system(size: 20)); Text("请接入可信 Wi‑Fi 或开启个人热点。").foregroundStyle(Signal.secondary) }
                }
                HStack { Text("代理协议"); Spacer(); Text("\(model.runtime.activeConnections) ACTIVE CONNECTIONS").font(.system(size: 9, design: .monospaced)).foregroundStyle(Signal.secondary) }
                HStack(spacing: 10) {
                    ProtocolCard(model: model, kind: .http)
                    ProtocolCard(model: model, kind: .socks5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }
}

private struct OrbitView: View {
    let phase: SessionPhase
    let reducedMotion: Bool
    let action: () -> Void
    @State private var animate = false
    var body: some View {
        ZStack {
            Circle().stroke(Signal.accent.opacity(0.08), lineWidth: 1).frame(width: 190, height: 190)
            Circle().stroke(Signal.accent.opacity(0.12), lineWidth: 1).frame(width: 170, height: 170)
            Circle().trim(from: 0, to: 0.7).stroke(Signal.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 190, height: 190).rotationEffect(.degrees(animate ? 360 : 0))
            Circle().trim(from: 0, to: 0.1).stroke(Signal.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round)).frame(width: 170, height: 170).rotationEffect(.degrees(animate ? -360 : 0))
            Circle().trim(from: 0.22, to: 0.46).stroke(AngularGradient(colors: [Signal.accent.opacity(0.12), Signal.accent, Signal.mint.opacity(0.35)], center: .center), style: StrokeStyle(lineWidth: 0.8, lineCap: .round)).frame(width: 146, height: 146).rotationEffect(.degrees(animate ? 180 : 0))
            Button(action: action) {
                VStack(spacing: 9) { Image(systemName: phase == .failed ? "exclamationmark.triangle" : "power").font(.system(size: 28, weight: .light)); Text(phase == .running ? "停止代理" : "启动代理").font(.system(size: 17, weight: .medium)); Text(phase == .running ? "TAP TO STOP" : "TAP TO START").font(.system(size: 9, design: .monospaced)).tracking(1.7).foregroundStyle(Signal.secondary) }
                    .foregroundStyle(phase == .running ? Signal.accent : Signal.secondary)
                    .frame(width: 124, height: 124)
                    .background(RadialGradient(colors: [Signal.accent.opacity(0.08), .clear], center: .center, startRadius: 0, endRadius: 70), in: Circle())
            }
        }
        .frame(maxWidth: .infinity).frame(height: 220)
        .onAppear { if !reducedMotion { animate = true } }
        .onChange(of: reducedMotion) { value in animate = !value }
        .animation(reducedMotion ? nil : .linear(duration: 20).repeatForever(autoreverses: false), value: animate)
    }
}

private struct AddressCard: View {
    let host: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("YOUR LOCAL ADDRESS").font(.system(size: 10, design: .monospaced)).tracking(1.8); Spacer(); Text("局域网 · IPv4").font(.system(size: 10)) }
            HStack { Text(host).font(.system(size: 28, design: .monospaced)); Spacer(); Image(systemName: "square.on.square").font(.system(size: 24)) }
            Divider().overlay(Color.black.opacity(0.2))
            HStack { Text("客户端填写此地址，不是 0.0.0.0").font(.system(size: 11)); Spacer(); Text("连接设备 →").font(.system(size: 11, weight: .bold)) }
        }
        .foregroundStyle(Color(red: 0.09, green: 0.14, blue: 0.04))
        .padding(20).background(Signal.accent, in: RoundedRectangle(cornerRadius: 21))
    }
}

private struct Metric: View { let title: String; let value: String; let unit: String; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 11)).foregroundStyle(Signal.secondary); HStack(alignment: .lastTextBaseline, spacing: 5) { Text(value).font(.system(size: 27, design: .monospaced)); Text(unit).font(.system(size: 10)).foregroundStyle(Signal.secondary) } }.frame(maxWidth: .infinity, alignment: .leading) } }

private struct ProtocolCard: View {
    @ObservedObject var model: APSViewModel
    let kind: ProxyProtocol
    var body: some View {
        Button { model.showPortEditor = kind } label: {
            VStack(alignment: .leading, spacing: 12) { HStack { Text(kind.rawValue); Spacer(); Text(model.runtime.config?.enabled(for: kind) == true ? "运行中" : "已选用").font(.system(size: 10)).foregroundStyle(Signal.accent) }; Text(":\(model.settings.port(for: kind))").font(.system(size: 18, design: .monospaced)) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Signal.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Signal.border, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

private struct ConnectView: View {
    @ObservedObject var model: APSViewModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 15) { PageHeading(eyebrow: "MAKE THE CONNECTION", title: "下一台，连接。", subtitle: "让客户端与手机处于同一可信局域网。"); Picker("协议", selection: $model.selectedProtocol) { ForEach(ProxyProtocol.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented); if let host = model.host, let text = model.configText(for: model.selectedProtocol) { SignalCard { VStack(alignment: .leading, spacing: 12) { Text("CONNECTION PASS").font(.system(size: 10, design: .monospaced)); Text("\(model.selectedProtocol.rawValue) / TCP").font(.system(size: 22, design: .monospaced)); Text(host).font(.system(size: 21, design: .monospaced)); Text("PORT  \(model.settings.port(for: model.selectedProtocol))    AUTH  无").font(.system(size: 12, design: .monospaced)); ShareLink(item: text) { Label("分享配置文本", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent) } } } else { SignalCard { Text("连接可信 Wi‑Fi 或开启手机热点后再继续").font(.title3); Text("发现可达地址后才能生成连接配置。").foregroundStyle(Signal.secondary) } } }.padding(.horizontal, 20).padding(.bottom, 18) }
    }
}

private struct ActivityView: View { @ObservedObject var model: APSViewModel; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 15) { PageHeading(eyebrow: "LIVE / IN THIS SESSION", title: "看见每次流动。", subtitle: "仅展示当前会话，不上传、不建立云端历史。"); SignalCard { Text(model.runtime.running ? "传输速率 · LIVE" : "等待真实会话"); Text("\(model.runtime.bytesReceived) B received · \(model.runtime.bytesSent) B sent").font(.system(size: 13, design: .monospaced)).foregroundStyle(Signal.secondary) }; Text("会话日志").font(.headline); Text(model.runtime.log.isEmpty ? "尚无会话记录。启动服务后，生命周期事件会出现在这里。" : model.runtime.log.map(\.message).joined(separator: "\n")).foregroundStyle(Signal.secondary) }.padding(.horizontal, 20).padding(.bottom, 18) } } }

private struct SettingsView: View { @ObservedObject var model: APSViewModel; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 17) { PageHeading(eyebrow: "FINE-TUNE YOUR SIGNAL", title: "少一点干扰。", subtitle: "只保留与你的连接有关的设置。"); SignalCard { ForEach(ProxyProtocol.allCases) { kind in Button("\(kind.rawValue)  :\(model.settings.port(for: kind))", systemImage: "slider.horizontal.3") { model.showPortEditor = kind }.foregroundStyle(Signal.text); Divider().overlay(Signal.border) }; Toggle("减少动态效果", isOn: $model.settings.reducedMotion) }; Button("连接有边界。查看风险说明") { model.showRisk = true }.foregroundStyle(Signal.warning) }.padding(.horizontal, 20).padding(.bottom, 18) } } }

private struct PortEditor: View { @ObservedObject var model: APSViewModel; let kind: ProxyProtocol; @Environment(\.dismiss) private var dismiss; @State private var port = ""; @State private var enabled = true; var body: some View { NavigationStack { Form { TextField("端口", text: $port).keyboardType(.numberPad); Toggle("选用此协议", isOn: $enabled); Text("监听 0.0.0.0:\(port)。客户端填写手机的局域网地址。\nHTTP 支持 HTTPS CONNECT；SOCKS5 仅支持 TCP CONNECT。") }.navigationTitle("\(kind.rawValue) 监听配置").toolbar { ToolbarItem(placement: .confirmationAction) { Button("保存") { model.save(protocol: kind, port: Int(port) ?? kind.defaultPort, enabled: enabled); dismiss() } } } }.onAppear { port = "\(model.settings.port(for: kind))"; enabled = model.settings.enabled(for: kind) } } }

private struct RiskSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { ScrollView { Text("这是局域网代理服务器，不是 VPN 客户端。服务没有用户名和密码认证，只应在可信 Wi‑Fi 或手机热点中使用。iOS 普通 App 进入后台后可能被系统挂起；锁屏常驻需要额外 Network Extension 方案。\n\nHTTP 支持 HTTPS CONNECT；SOCKS5 仅支持 TCP CONNECT，不支持 UDP 或 BIND。") .foregroundStyle(Signal.secondary).padding() }.navigationTitle("连接有边界").toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回") { dismiss() } } } } } }

private extension Image { func symbol(_ name: String) -> some View { self } }

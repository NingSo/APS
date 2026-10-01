import Combine
import Foundation
import Network
import UIKit

enum Screen: String, CaseIterable { case overview, connect, activity, settings, diagnostics }
enum InfoTopic: String { case risk, background, route, theme, about }
enum SheetRoute: Identifiable, Equatable {
    case consent(String, Int), stop, port(ProxyKind), share(ProxyKind), information(InfoTopic), export
    var id: String { String(describing: self) }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var preferences: Preferences
    @Published private(set) var session = SessionSnapshot()
    @Published private(set) var addresses: [LocalAddress] = []
    @Published private(set) var selectedAddress: String?
    @Published var page: Screen = .overview
    @Published var selectedTab: Screen = .overview
    @Published var sheet: SheetRoute?
    @Published var protocolChoice: ProxyKind = .http
    @Published var clientChoice = 0
    @Published var logQuery = ""
    @Published var logFilter: EventLevel?
    @Published var toast: String?
    @Published private(set) var foreground = true
    private(set) var networkRevision = 0
    private var backPage: Screen = .overview
    private var lastRevision = 0
    private var pending: Phase?
    private let engine: ProxyEngine
    private let defaults: UserDefaults
    private var monitor: NWPathMonitor?
    private var toastTask: Task<Void, Never>?
    private var pathSignature: String?
    private var fixture = false
    static let preferencesKey = "aps.ios.preferences.v1"

    init(defaults: UserDefaults = .standard, monitorNetwork: Bool = true, engine: ProxyEngine = ProxyEngine()) {
        self.defaults = defaults
        self.engine = engine
        if let data = defaults.data(forKey: Self.preferencesKey),
           let saved = try? JSONDecoder().decode(Preferences.self, from: data), saved.valid {
            preferences = saved
        } else { preferences = Preferences() }
        engine.observe { [weak self] state in
            Task { @MainActor in self?.receive(state) }
        }
        if monitorNetwork {
            refreshNetwork()
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                let signature = "\(path.status):" + path.availableInterfaces.map { "\($0.name):\($0.index)" }.sorted().joined(separator: ",")
                Task { @MainActor in
                    guard let self = self else { return }
                    let changed = self.pathSignature != nil && self.pathSignature != signature
                    self.pathSignature = signature
                    self.refreshNetwork(forceInvalidation: changed)
                }
            }
            self.monitor = monitor
            monitor.start(queue: DispatchQueue(label: "aps.path.monitor"))
        }
    }
    deinit { monitor?.cancel(); toastTask?.cancel() }
    var host: String? {
        addresses.contains(where: { $0.host == selectedAddress }) ? selectedAddress : addresses.first?.host
    }
    var filteredEvents: [SessionEvent] {
        session.events.reversed().filter {
            (logFilter == nil || $0.level == logFilter) && (logQuery.isEmpty || $0.text.localizedCaseInsensitiveContains(logQuery))
        }
    }
    func navigate(_ target: Screen) {
        if [.overview, .connect, .activity].contains(target) { selectedTab = target; backPage = target }
        else { backPage = page }
        page = target
    }
    func back() {
        page = backPage == .diagnostics ? selectedTab : backPage
        backPage = selectedTab
    }
    func power() {
        guard !session.phase.busy else { return }
        if session.phase == .running { sheet = .stop }
        else if session.phase == .failed { sheet = .port(.http) }
        else { requestConsent() }
    }
    func requestConsent() {
        refreshNetwork()
        guard preferences.hasProtocol else { navigate(.settings); note("请先选用至少一种协议"); return }
        guard let host = host else { navigate(.diagnostics); note("未发现局域网地址"); return }
        sheet = .consent(host, networkRevision)
    }
    func confirmStart(host: String, revision: Int) {
        guard foreground, !session.phase.busy, preferences.hasProtocol, preferences.valid,
              self.host == host, networkRevision == revision else {
            sheet = nil; note("网络或配置已改变，请重新确认后启动"); return
        }
        sheet = nil; pending = .starting; session.phase = .starting
        engine.start(preferences, localHosts: Set(addresses.map(\.host)))
    }
    func stop(reason: String? = nil) {
        sheet = nil
        guard session.phase != .stopped else { return }
        pending = .stopping; session.phase = .stopping; updateIdleTimer()
        engine.stop()
        if let reason = reason { note(reason) }
    }
    @discardableResult
    func save(_ kind: ProxyKind, text: String, enabled: Bool) -> Bool {
        let other = preferences.port(kind == .http ? .socks5 : .http)
        guard Preferences.portError(text, other: other) == nil,
              let port = Int(text), !session.phase.busy else { return false }
        let wasRunning = session.phase == .running
        let wasFailed = session.phase == .failed
        preferences = preferences.editing(kind, port: port, enabled: enabled)
        persist(); sheet = nil
        if wasRunning {
            pending = preferences.hasProtocol ? .starting : .stopping
            session.phase = pending!
            engine.reconfigure(preferences, localHosts: Set(addresses.map(\.host)))
        } else if wasFailed, preferences.hasProtocol { requestConsent() }
        else { note("配置已保存，下次启动时生效") }
        return true
    }
    func setReduceMotion(_ enabled: Bool) { preferences.reduceMotion = enabled; persist() }
    func setKeepAwake(_ enabled: Bool) { preferences.keepAwake = enabled; persist(); updateIdleTimer() }
    func selectAddress(_ address: String) {
        guard addresses.contains(where: { $0.host == address }), selectedAddress != address else { return }
        selectedAddress = address; networkRevision += 1; invalidateSharing()
        note("连接地址已更新，请同步修改客户端")
    }
    func refreshNetwork(forceInvalidation: Bool = false) {
        guard !fixture else { return }
        let next = LocalNetwork.addresses()
        let changed = next != addresses || forceInvalidation
        addresses = next
        if !next.contains(where: { $0.host == selectedAddress }) { selectedAddress = next.first?.host }
        if changed {
            networkRevision += 1; invalidateSharing()
            if session.phase == .running || session.phase == .starting {
                stop(reason: "网络已改变，代理已停止。请确认新网络可信后重新启动。")
            }
        }
    }
    private func invalidateSharing() {
        switch sheet { case .consent, .share: sheet = nil; default: break }
    }
    func setForeground(_ active: Bool, background: Bool) {
        foreground = active; updateIdleTimer()
        if background { stop(reason: "进入后台后代理已停止，返回后需手动启动。") }
        else if active { refreshNetwork() }
    }
    func copy(_ value: String) { UIPasteboard.general.string = value; note("已复制") }
    func note(_ text: String) {
        toastTask?.cancel(); toast = text
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
    func exportText() -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        return "APS / SIGNAL — current session\nReview network details before sharing.\n\n" + session.events.map {
            "\(formatter.string(from: $0.time)) [\($0.level.rawValue)] \($0.text)"
        }.joined(separator: "\n")
    }
    private func receive(_ state: SessionSnapshot) {
        guard !fixture, state.revision > lastRevision else { return }
        lastRevision = state.revision
        if pending == .starting && state.phase == .stopped { return }
        if pending == .stopping && (state.phase == .running || state.phase == .starting) { return }
        pending = nil; session = state; updateIdleTimer()
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.preferencesKey)
    }
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = foreground && session.phase == .running && preferences.keepAwake
    }

    #if DEBUG && targetEnvironment(simulator)
    func useFixture(_ name: String) {
        fixture = true; preferences.reduceMotion = name != "motion"
        addresses = name == "no-address" ? [] : [LocalAddress(host: "192.0.2.10", interface: "fixture")]
        selectedAddress = addresses.first?.host
        if name == "running" || name == "motion" {
            session.phase = .running; session.configuration = preferences; session.elapsed = 754
            session.active = 6; session.total = 134; session.received = 147849216; session.sent = 15099494
            session.receiveRate = 1280000; session.sendRate = 124000
            session.samples = (0..<60).map {
                TrafficSample(uptime: Double($0), received: Int64($0 % 13 * 74000 + 200000), sent: Int64($0 % 7 * 9000 + 14000))
            }
            session.log(.info, "本地监听自检通过 · HTTP / SOCKS5")
        } else if name == "failed" {
            session.phase = .failed; session.error = "HTTP 端口不可用"; session.log(.error, "HTTP 端口不可用")
        }
    }
    #endif
}

import Foundation

enum ProxyKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case http = "HTTP", socks5 = "SOCKS5"
    var id: String { rawValue }
}

struct Preferences: Equatable, Codable, Sendable {
    var httpEnabled = true
    var httpPort = 8080
    var socksEnabled = true
    var socksPort = 1080
    var reduceMotion = false
    var keepAwake = false

    var hasProtocol: Bool { httpEnabled || socksEnabled }
    var valid: Bool { (1...65535).contains(httpPort) && (1...65535).contains(socksPort) && httpPort != socksPort }
    func enabled(_ kind: ProxyKind) -> Bool { kind == .http ? httpEnabled : socksEnabled }
    func port(_ kind: ProxyKind) -> Int { kind == .http ? httpPort : socksPort }
    var ports: Set<Int> { Set(ProxyKind.allCases.filter(enabled).map(port)) }
    func editing(_ kind: ProxyKind, port: Int, enabled: Bool) -> Preferences {
        var next = self
        if kind == .http { next.httpPort = port; next.httpEnabled = enabled }
        else { next.socksPort = port; next.socksEnabled = enabled }
        return next
    }
    static func portError(_ text: String, other: Int) -> String? {
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let port = Int(text), (1...65535).contains(port) else { return "请输入 1–65535 之间的整数" }
        return port == other ? "HTTP 与 SOCKS5 必须使用不同端口" : nil
    }
}

enum Phase: String, Sendable {
    case stopped, starting, running, stopping, failed
    var busy: Bool { self == .starting || self == .stopping }
    var badge: String {
        switch self { case .stopped: return "STANDBY"; case .starting: return "VERIFYING"
        case .running: return "RUNNING"; case .stopping: return "STOPPING"; case .failed: return "FAILED" }
    }
    var title: String {
        switch self { case .stopped: return "让连接，发生。"; case .starting: return "正在唤醒连接。"
        case .running: return "连接，就绪。"; case .stopping: return "正在结束会话。"; case .failed: return "连接，需要处理。" }
    }
    var action: String {
        switch self { case .stopped: return "启动代理"; case .starting: return "正在校验"
        case .running: return "停止代理"; case .stopping: return "正在停止"; case .failed: return "重新启动" }
    }
}

enum EventLevel: String, CaseIterable, Sendable { case info = "INFO", warning = "WARN", error = "ERROR" }
struct SessionEvent: Identifiable, Equatable, Sendable {
    let id: Int
    let time: Date
    let level: EventLevel
    let text: String
}
struct TrafficSample: Identifiable, Equatable, Sendable {
    let uptime: TimeInterval
    let received: Int64
    let sent: Int64
    var id: TimeInterval { uptime }
}
struct SessionSnapshot: Sendable {
    var revision = 0
    var phase: Phase = .stopped
    var configuration: Preferences?
    var startedUptime: TimeInterval?
    var elapsed: TimeInterval = 0
    var received: Int64 = 0
    var sent: Int64 = 0
    var receiveRate: Int64 = 0
    var sendRate: Int64 = 0
    var active = 0
    var total: Int64 = 0
    var error: String?
    var samples: [TrafficSample] = []
    var events: [SessionEvent] = []
    func listening(_ kind: ProxyKind, preferences: Preferences) -> Bool {
        phase == .running && configuration?.enabled(kind) == true && configuration?.port(kind) == preferences.port(kind)
    }
    mutating func log(_ level: EventLevel, _ text: String) {
        let next = (events.last?.id ?? 0) + 1
        events.append(SessionEvent(id: next, time: Date(), level: level, text: text))
        if events.count > 200 { events.removeFirst(events.count - 200) }
    }
}
struct RateMeter {
    private var lastTime: TimeInterval?
    private var lastReceived: Int64 = 0
    private var lastSent: Int64 = 0
    mutating func sample(now: TimeInterval, received: Int64, sent: Int64) -> TrafficSample {
        defer { lastTime = now; lastReceived = received; lastSent = sent }
        guard let previous = lastTime, now > previous else { return TrafficSample(uptime: now, received: 0, sent: 0) }
        let delta = now - previous
        return TrafficSample(uptime: now,
            received: Int64(Double(max(0, received - lastReceived)) / delta),
            sent: Int64(Double(max(0, sent - lastSent)) / delta))
    }
}

struct ByteAmount {
    let value: String
    let unit: String
    init(_ count: Int64, rate: Bool = false) {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var value = Double(max(0, count)); var index = 0
        while value >= 1024 && index < units.count - 1 { value /= 1024; index += 1 }
        self.value = String(format: index == 0 || value >= 100 ? "%.0f" : "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
        unit = units[index] + (rate ? "/s" : "")
    }
}
func sessionDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
}
func configurationText(host: String, preferences: Preferences, kind: ProxyKind) -> String {
    "\(kind.rawValue) proxy\nHost: \(host)\nPort: \(preferences.port(kind))\nAuthentication: none\nTrusted LAN only"
}
func clientCommand(host: String, preferences: Preferences, kind: ProxyKind) -> String {
    "curl --proxy \(kind == .http ? "http" : "socks5h")://\(host):\(preferences.port(kind)) https://example.com"
}

enum ProxyFailure: LocalizedError, Equatable {
    case invalidSettings, malformedHTTP, headerTooLarge, invalidSOCKS, noAuthentication, unsupportedCommand, unsupportedAddress, timeout, proxyLoop
    var errorDescription: String? {
        switch self {
        case .invalidSettings: return "端口必须合法且不同，并选用至少一种协议"
        case .malformedHTTP: return "HTTP 请求格式不正确；HTTPS 请使用 CONNECT"
        case .headerTooLarge: return "HTTP 请求头超过 32 KiB 限制"
        case .invalidSOCKS: return "SOCKS5 握手格式不正确"
        case .noAuthentication: return "客户端未提供无鉴权方式"
        case .unsupportedCommand: return "只支持 SOCKS5 TCP CONNECT，不支持 UDP 或 BIND"
        case .unsupportedAddress: return "不支持的目标地址格式"
        case .timeout: return "连接或本地监听校验超时"
        case .proxyLoop: return "已阻止代理回环连接"
        }
    }
}

import Foundation

public enum ProxyProtocol: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case http = "HTTP"
    case socks5 = "SOCKS5"

    public var id: String { rawValue }
    public var defaultPort: Int { self == .http ? 8080 : 1080 }
}

public struct ProxySettings: Equatable, Codable, Sendable {
    public var httpEnabled: Bool
    public var httpPort: Int
    public var socksEnabled: Bool
    public var socksPort: Int
    public var reducedMotion: Bool

    public init(
        httpEnabled: Bool = true,
        httpPort: Int = 8080,
        socksEnabled: Bool = true,
        socksPort: Int = 1080,
        reducedMotion: Bool = false
    ) {
        self.httpEnabled = httpEnabled
        self.httpPort = httpPort
        self.socksEnabled = socksEnabled
        self.socksPort = socksPort
        self.reducedMotion = reducedMotion
    }

    public var hasProtocol: Bool { httpEnabled || socksEnabled }

    public func port(for kind: ProxyProtocol) -> Int {
        kind == .http ? httpPort : socksPort
    }

    public func enabled(for kind: ProxyProtocol) -> Bool {
        kind == .http ? httpEnabled : socksEnabled
    }

    public func with(kind: ProxyProtocol, port: Int, enabled: Bool) -> ProxySettings {
        var copy = self
        if kind == .http {
            copy.httpPort = port
            copy.httpEnabled = enabled
        } else {
            copy.socksPort = port
            copy.socksEnabled = enabled
        }
        return copy
    }

    /// Android's model calls this argument `protocol`; keep the label for cross-platform UI code.
    public func with(`protocol` kind: ProxyProtocol, port: Int, enabled: Bool) -> ProxySettings {
        with(kind: kind, port: port, enabled: enabled)
    }

    public var validPorts: Bool {
        (1...65_535).contains(httpPort) &&
        (1...65_535).contains(socksPort) &&
        (!httpEnabled || !socksEnabled || httpPort != socksPort)
    }
}

public enum SessionPhase: String, Codable, Sendable {
    case stopped, starting, running, stopping, failed

    public var label: String {
        switch self {
        case .stopped: "STANDBY"
        case .starting: "VERIFYING"
        case .running: "RUNNING"
        case .stopping: "STOPPING"
        case .failed: "FAILED"
        }
    }
}

public enum LogLevel: String, Codable, Sendable {
    case info, warning, error
}

public struct LogEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: Int64
    public let date: Date
    public let level: LogLevel
    public let message: String

    public init(id: Int64, date: Date = Date(), level: LogLevel, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.message = message
    }
}

public struct RateSample: Identifiable, Equatable, Codable, Sendable {
    public let at: Date
    public let receivedPerSecond: Int64
    public let sentPerSecond: Int64

    public var id: Date { at }

    public init(at: Date = Date(), receivedPerSecond: Int64, sentPerSecond: Int64) {
        self.at = at
        self.receivedPerSecond = receivedPerSecond
        self.sentPerSecond = sentPerSecond
    }
}

public struct RuntimeSnapshot: Equatable, Sendable {
    public var phase: SessionPhase
    public var config: ProxySettings?
    public var startedAt: Date?
    public var bytesReceived: Int64
    public var bytesSent: Int64
    public var activeConnections: Int
    public var totalConnections: Int64
    public var lastError: String?
    public var samples: [RateSample]
    public var log: [LogEntry]

    public init(
        phase: SessionPhase = .stopped,
        config: ProxySettings? = nil,
        startedAt: Date? = nil,
        bytesReceived: Int64 = 0,
        bytesSent: Int64 = 0,
        activeConnections: Int = 0,
        totalConnections: Int64 = 0,
        lastError: String? = nil,
        samples: [RateSample] = [],
        log: [LogEntry] = []
    ) {
        self.phase = phase
        self.config = config
        self.startedAt = startedAt
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.activeConnections = activeConnections
        self.totalConnections = totalConnections
        self.lastError = lastError
        self.samples = samples
        self.log = log
    }

    public var running: Bool { phase == .running }
    public var busy: Bool { phase == .starting || phase == .stopping }
    public var elapsed: TimeInterval { startedAt.map { Date().timeIntervalSince($0) } ?? 0 }
}

public enum ProxyServerEvent: Sendable {
    case accepted(protocol: ProxyProtocol)
    case closed
    case bytesReceived(Int)
    case bytesSent(Int)
    case failed(String)
}

public enum ProxyError: LocalizedError, Equatable, Sendable {
    case invalidConfiguration
    case listenerUnavailable(ProxyProtocol, Int)
    case connectionFailed
    case unsupportedCommand
    case malformedRequest

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Invalid proxy configuration"
        case let .listenerUnavailable(kind, port): "\(kind.rawValue) port \(port) is unavailable"
        case .connectionFailed: "Unable to connect to the requested target"
        case .unsupportedCommand: "Only TCP CONNECT is supported"
        case .malformedRequest: "Malformed proxy request"
        }
    }
}

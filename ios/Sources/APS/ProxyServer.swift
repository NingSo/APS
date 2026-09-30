import Foundation
import Network

/// A foreground, LAN-facing HTTP/SOCKS5 TCP proxy. All socket work is serialized on `queue`.
/// It deliberately has no authentication, UDP forwarding, BIND or VPN integration.
public final class ProxyServer: @unchecked Sendable {
    public typealias Completion = @Sendable (Result<Void, Error>) -> Void

    private let queue = DispatchQueue(label: "com.ningso.aps.proxy", qos: .userInitiated)
    private var listeners: [ProxyProtocol: NWListener] = [:]
    private var sessions: [ObjectIdentifier: ClientSession] = [:]
    private var runningConfiguration: ProxySettings?
    private var pendingConfiguration: ProxySettings?
    private var startCompletion: Completion?
    private var listenersReady = 0
    private var listenersExpected = 0

    public var onEvent: (@Sendable (ProxyServerEvent) -> Void)?

    public init() {}

    public var configuration: ProxySettings? { queue.sync { runningConfiguration } }
    public var isRunning: Bool { queue.sync { runningConfiguration != nil } }

    public func start(settings: ProxySettings, completion: @escaping Completion) {
        queue.async { [weak self] in
            guard let self else { return }
            guard settings.validPorts, settings.hasProtocol else {
                completion(.failure(ProxyError.invalidConfiguration))
                return
            }
            guard self.runningConfiguration == nil else {
                completion(.failure(ProxyError.listenerUnavailable(.http, settings.httpPort)))
                return
            }
            do {
                self.listenersReady = 0
                self.listenersExpected = [ProxyProtocol.http, .socks5].filter { settings.enabled(for: $0) }.count
                self.pendingConfiguration = settings
                self.startCompletion = completion
                if settings.httpEnabled { try self.bind(.http, port: settings.httpPort) }
                if settings.socksEnabled { try self.bind(.socks5, port: settings.socksPort) }
            } catch {
                self.cancelListeners()
                self.pendingConfiguration = nil
                self.startCompletion = nil
                completion(.failure(error))
            }
        }
    }

    public func stop(completion: @escaping @Sendable () -> Void = {}) {
        queue.async { [weak self] in
            guard let self else { completion(); return }
            self.runningConfiguration = nil
            self.pendingConfiguration = nil
            self.startCompletion = nil
            self.cancelListeners()
            self.sessions.values.forEach { $0.cancel() }
            self.sessions.removeAll()
            completion()
        }
    }

    public func reconfigure(settings: ProxySettings, completion: @escaping Completion) {
        stop { [weak self] in
            self?.start(settings: settings, completion: completion)
        }
    }

    private func bind(_ kind: ProxyProtocol, port: Int) throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw ProxyError.listenerUnavailable(kind, port)
        }
        let listener = try NWListener(using: .tcp, on: endpointPort)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.queue.async {
                switch state {
                case .ready:
                    self.listenersReady += 1
                    if self.listenersReady == self.listenersExpected {
                        self.runningConfiguration = self.pendingConfiguration
                        let completion = self.startCompletion
                        self.startCompletion = nil
                        completion?(.success(()))
                    }
                case .failed(let error):
                    let completion = self.startCompletion
                    self.startCompletion = nil
                    self.cancelListeners()
                    self.pendingConfiguration = nil
                    completion?(.failure(ProxyError.listenerUnavailable(kind, port)))
                    self.emit(.failed(error.localizedDescription))
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.queue.async {
                let session = ClientSession(server: self, connection: connection, kind: kind)
                self.sessions[ObjectIdentifier(session)] = session
                self.emit(.accepted(protocol: kind))
                session.start()
            }
        }
        listeners[kind] = listener
        listener.start(queue: queue)
    }

    private func cancelListeners() {
        listeners.values.forEach { $0.cancel() }
        listeners.removeAll()
    }

    private func remove(_ session: ClientSession) {
        sessions.removeValue(forKey: ObjectIdentifier(session))
    }

    fileprivate func emit(_ event: ProxyServerEvent) {
        onEvent?(event)
    }

    private final class ClientSession: @unchecked Sendable {
        private enum Mode { case handshake, relay }

        private weak var server: ProxyServer?
        private let connection: NWConnection
        private let kind: ProxyProtocol
        private var remote: NWConnection?
        private var input = Data()
        private var mode: Mode = .handshake
        private var socksGreetingDone = false
        private var cancelled = false

        init(server: ProxyServer, connection: NWConnection, kind: ProxyProtocol) {
            self.server = server
            self.connection = connection
            self.kind = kind
        }

        func start() {
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .failed(let error):
                    self.server?.emit(.failed(error.localizedDescription))
                    self.cancel()
                case .cancelled:
                    self.server?.queue.async { [weak self] in
                        guard let self else { return }
                        self.server?.remove(self)
                        self.server?.emit(.closed)
                    }
                default:
                    break
                }
            }
            connection.start(queue: server?.queue ?? .main)
            receiveClient()
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            connection.cancel()
            remote?.cancel()
        }

        private func receiveClient() {
            guard !cancelled else { return }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.server?.queue.async {
                        guard !self.cancelled else { return }
                        self.server?.emit(.bytesReceived(data.count))
                        if self.mode == .relay {
                            self.sendToRemote(data)
                        } else {
                            self.input.append(data)
                            self.processHandshake()
                        }
                    }
                }
                if isComplete || error != nil { self.cancel() } else { self.receiveClient() }
            }
        }

        private func processHandshake() {
            switch kind {
            case .http: processHTTP()
            case .socks5: processSOCKS5()
            }
        }

        private func processHTTP() {
            let marker = Data([13, 10, 13, 10])
            guard let end = input.range(of: marker) else { return }
            guard let header = String(data: input[..<end.lowerBound], encoding: .utf8) else {
                failHTTP(); return
            }
            var lines = header.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else { failHTTP(); return }
            let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { failHTTP(); return }
            let method = parts[0].uppercased()
            let target: (host: String, port: Int, tunnel: Bool, payload: Data)?
            if method == "CONNECT" {
                let hostPort = parts[1].split(separator: ":", maxSplits: 1).map(String.init)
                guard let host = hostPort.first, !host.isEmpty else { failHTTP(); return }
                let port = hostPort.dropFirst().first.flatMap(Int.init) ?? 443
                target = makeTarget(host: host, port: port, tunnel: true, payload: Data())
            } else {
                let url = URL(string: parts[1])
                let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
                let host = components?.host ?? headerValue("Host", lines: lines)
                guard let host, !host.isEmpty else { failHTTP(); return }
                let port = components?.port ?? (components?.scheme?.lowercased() == "https" ? 443 : 80)
                let path = (components?.percentEncodedPath.isEmpty == false ? components!.percentEncodedPath : "/") +
                    (components?.percentEncodedQuery.map { "?\($0)" } ?? "")
                lines[0] = "\(method) \(path) \(parts[2])"
                lines = lines.filter { !$0.lowercased().hasPrefix("proxy-connection:") && !$0.lowercased().hasPrefix("proxy-authorization:") }
                let rewritten = Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
                let bodyStart = end.upperBound
                target = makeTarget(host: host, port: port, tunnel: false, payload: rewritten + input[bodyStart...])
            }
            input.removeAll()
            guard let target else { failHTTP(); return }
            connectRemote(host: target.host, port: target.port, tunnel: target.tunnel, initialPayload: target.payload)
        }

        private func makeTarget(host: String, port: Int, tunnel: Bool, payload: Data) -> (host: String, port: Int, tunnel: Bool, payload: Data)? {
            guard (1...65_535).contains(port), let _ = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
            return (host, port, tunnel, payload)
        }

        private func processSOCKS5() {
            if !socksGreetingDone {
                guard input.count >= 2, input[0] == 5 else { failSOCKS(); return }
                let methodCount = Int(input[1])
                guard input.count >= methodCount + 2 else { return }
                let methods = input[2..<(methodCount + 2)]
                input.removeFirst(methodCount + 2)
                guard methods.contains(0) else {
                    sendToClient(Data([5, 255]))
                    cancel()
                    return
                }
                socksGreetingDone = true
                sendToClient(Data([5, 0]))
            }
            guard input.count >= 4, input[0] == 5 else { return }
            guard input[1] == 1 else {
                sendToClient(socksReply(status: 7, address: "0.0.0.0", port: 0))
                cancel(); return
            }
            let addressType = input[3]
            var offset = 4
            let host: String
            switch addressType {
            case 1:
                guard input.count >= offset + 4 + 2 else { return }
                host = input[offset..<(offset + 4)].map(String.init).joined(separator: ".")
                offset += 4
            case 3:
                guard input.count > offset else { return }
                let count = Int(input[offset]); offset += 1
                guard input.count >= offset + count + 2 else { return }
                host = String(decoding: input[offset..<(offset + count)], as: UTF8.self)
                offset += count
            case 4:
                guard input.count >= offset + 16 + 2 else { return }
                let bytes = Array(input[offset..<(offset + 16)])
                host = stride(from: 0, to: 16, by: 2)
                    .map { String(format: "%x", (UInt16(bytes[$0]) << 8) | UInt16(bytes[$0 + 1])) }
                    .joined(separator: ":")
                offset += 16
            default:
                failSOCKS(); return
            }
            guard input.count >= offset + 2 else { return }
            let port = (Int(input[offset]) << 8) | Int(input[offset + 1])
            input.removeAll()
            connectSOCKS(host: host, port: port, addressType: addressType)
        }

        private func connectSOCKS(host: String, port: Int, addressType: UInt8) {
            guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { failSOCKS(); return }
            let target = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
            remote = target
            target.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.sendToClient(self.socksReply(status: 0, address: "0.0.0.0", port: 0))
                    self.mode = .relay
                    self.startRemoteReceive()
                case .failed:
                    self.sendToClient(self.socksReply(status: 5, address: "0.0.0.0", port: 0))
                    self.cancel()
                default: break
                }
            }
            target.start(queue: server?.queue ?? .main)
        }

        private func connectRemote(host: String, port: Int, tunnel: Bool, initialPayload: Data) {
            guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { failHTTP(); return }
            let target = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
            remote = target
            target.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if tunnel { self.sendToClient(Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8)) }
                    else if !initialPayload.isEmpty { self.sendToRemote(initialPayload) }
                    self.mode = .relay
                    self.startRemoteReceive()
                case .failed:
                    self.sendToClient(Data("HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8))
                    self.cancel()
                default: break
                }
            }
            target.start(queue: server?.queue ?? .main)
        }

        private func startRemoteReceive() {
            guard !cancelled else { return }
            remote?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
                guard let self else { return }
                if let data, !data.isEmpty { self.sendToClient(data) }
                if complete || error != nil { self.cancel() } else { self.startRemoteReceive() }
            }
        }

        private func sendToRemote(_ data: Data) {
            remote?.send(content: data, completion: .contentProcessed { [weak self] error in
                if error == nil { self?.server?.emit(.bytesSent(data.count)) } else { self?.cancel() }
            })
        }

        private func sendToClient(_ data: Data) {
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if error == nil { self?.server?.emit(.bytesSent(data.count)) } else { self?.cancel() }
            })
        }

        private func failHTTP() {
            sendToClient(Data("HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8))
            cancel()
        }

        private func failSOCKS() {
            sendToClient(socksReply(status: 1, address: "0.0.0.0", port: 0))
            cancel()
        }

        private func socksReply(status: UInt8, address: String, port: Int) -> Data {
            Data([5, status, 0, 1, 0, 0, 0, 0, UInt8((port >> 8) & 0xff), UInt8(port & 0xff)])
        }

        private func headerValue(_ name: String, lines: [String]) -> String? {
            lines.dropFirst().first { $0.lowercased().hasPrefix(name.lowercased() + ":") }?.split(separator: ":", maxSplits: 1).dropFirst().first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }
}

private extension Data {
    static func + (lhs: Data, rhs: Data.SubSequence) -> Data {
        var result = lhs
        result.append(contentsOf: rhs)
        return result
    }
}

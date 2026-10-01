import Foundation
import Network

/// Every listener, connection, counter and callback is confined to this serial queue.
/// The application never uses Network Extension or claims the system VPN slot.
final class ProxyEngine: @unchecked Sendable {
    typealias Observer = @Sendable (SessionSnapshot) -> Void
    private let queue = DispatchQueue(label: "com.ningso.aps.ios.engine", qos: .userInitiated)
    private var observer: Observer?
    private var snapshot = SessionSnapshot()
    private var revision = 0
    private var generation = 0
    private var listeners: [ProxyKind: NWListener] = [:]
    private var probes: [ProxyKind: NWConnection] = [:]
    private var probePeers: [ObjectIdentifier: NWConnection] = [:]
    private var tokens: [ProxyKind: Data] = [:]
    private var verified: Set<ProxyKind> = []
    private var clients: [ObjectIdentifier: Relay] = [:]
    private var meter = RateMeter()
    private var ticker: DispatchSourceTimer?
    private var startTimeout: DispatchWorkItem?
    private var localHosts: Set<String> = []
    private let allowLocalTestClients: Bool

    // Only XCTest uses this seam. The app always uses the default self-connection protection.
    init(allowLocalTestClients: Bool = false) { self.allowLocalTestClients = allowLocalTestClients }
    func observe(_ observer: @escaping Observer) { queue.async { self.observer = observer; self.publish() } }
    func start(_ preferences: Preferences, localHosts: Set<String>) {
        queue.async {
            guard preferences.valid, preferences.hasProtocol else { self.fail(ProxyFailure.invalidSettings.localizedDescription); return }
            guard !self.snapshot.phase.busy else { return }
            self.transition(to: preferences, localHosts: localHosts)
        }
    }
    func stop() { queue.async { self.transition(to: nil, localHosts: []) } }
    func reconfigure(_ preferences: Preferences, localHosts: Set<String>) {
        queue.async {
            guard preferences.valid, !self.snapshot.phase.busy else { return }
            self.transition(to: preferences.hasProtocol ? preferences : nil, localHosts: localHosts)
        }
    }
    private func transition(to preferences: Preferences?, localHosts: Set<String>) {
        generation += 1
        let token = generation
        snapshot.phase = preferences == nil ? .stopping : .starting
        snapshot.configuration = nil
        publish()
        releaseResources { [weak self] in
            guard let self, self.generation == token else { return }
            self.snapshot = SessionSnapshot()
            self.localHosts = localHosts
            guard let preferences else { self.publish(); return }
            self.snapshot.phase = .starting
            self.snapshot.configuration = preferences
            self.snapshot.log(.info, "绑定端口 · 校验本地监听")
            self.publish()
            do {
                for kind in ProxyKind.allCases where preferences.enabled(kind) { try self.bind(kind, port: preferences.port(kind), generation: token) }
                let timeout = DispatchWorkItem { [weak self] in
                    guard let self, self.generation == token, self.snapshot.phase == .starting else { return }
                    self.fail(ProxyFailure.timeout.localizedDescription)
                }
                self.startTimeout = timeout
                self.queue.asyncAfter(deadline: .now() + 10, execute: timeout)
            } catch { self.fail(error.localizedDescription) }
        }
    }
    private func bind(_ kind: ProxyKind, port: Int, generation: Int) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "0.0.0.0", port: NWEndpoint.Port(rawValue: UInt16(port))!)
        let listener = try NWListener(using: parameters)
        listeners[kind] = listener
        listener.stateUpdateHandler = { [weak self] state in
            guard let self, self.generation == generation else { return }
            switch state {
            case .ready: self.verify(kind, port: port, generation: generation)
            case .failed(let error): self.fail("\(kind.rawValue) :\(port) 无法监听：\(error.localizedDescription)")
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self, self.generation == generation else { connection.cancel(); return }
            let host = self.remoteHost(connection)
            if host.hasPrefix("127."), let nonce = self.tokens[kind] {
                self.answerProbe(connection, nonce: nonce, generation: generation); return
            }
            guard self.snapshot.phase == .running, self.clients.count < 256 else { connection.cancel(); return }
            if !self.allowLocalTestClients && (host.hasPrefix("127.") || host == "::1" || self.localHosts.contains(host)) {
                connection.cancel(); self.warning(ProxyFailure.proxyLoop.localizedDescription); return
            }
            let relay = Relay(engine: self, client: connection, kind: kind, generation: generation)
            self.clients[ObjectIdentifier(relay)] = relay
            self.snapshot.active += 1; self.snapshot.total += 1
            relay.start()
        }
        listener.start(queue: queue)
    }
    private func verify(_ kind: ProxyKind, port: Int, generation: Int) {
        guard probes[kind] == nil, snapshot.phase == .starting else { return }
        let nonce = Data(UUID().uuidString.utf8)
        tokens[kind] = nonce
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)
        probes[kind] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, self.generation == generation else { return }
            switch state {
            case .ready:
                connection.send(content: nonce, completion: .contentProcessed { [weak self, weak connection] error in
                    guard let self, let connection, self.generation == generation else { return }
                    guard error == nil else { self.fail("本地监听校验失败"); return }
                    connection.receive(minimumIncompleteLength: nonce.count, maximumLength: nonce.count) { [weak self] data, _, _, error in
                        guard let self, self.generation == generation, self.snapshot.phase == .starting else { return }
                        guard error == nil, data == nonce else { self.fail("本地监听校验失败"); return }
                        self.tokens.removeValue(forKey: kind)
                        self.probes.removeValue(forKey: kind)?.cancel()
                        self.verified.insert(kind)
                        if self.verified.count == self.listeners.count { self.didStart() }
                    }
                })
            case .failed: self.fail("本地监听校验失败")
            default: break
            }
        }
        connection.start(queue: queue)
    }
    private func answerProbe(_ connection: NWConnection, nonce: Data, generation: Int) {
        let id = ObjectIdentifier(connection)
        probePeers[id] = connection
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: nonce.count, maximumLength: nonce.count) { [weak self, weak connection] data, _, _, error in
            guard let self, let connection, self.generation == generation else { return }
            guard error == nil, data == nonce else { connection.cancel(); self.probePeers.removeValue(forKey: id); return }
            connection.send(content: nonce, completion: .contentProcessed { [weak self, weak connection] _ in
                connection?.cancel(); self?.probePeers.removeValue(forKey: id)
            })
        }
    }
    private func didStart() {
        startTimeout?.cancel(); startTimeout = nil
        snapshot.phase = .running
        snapshot.startedUptime = ProcessInfo.processInfo.systemUptime
        snapshot.log(.info, "本地监听自检通过 · " + verified.map(\.rawValue).sorted().joined(separator: " / "))
        meter = RateMeter()
        _ = meter.sample(now: ProcessInfo.processInfo.systemUptime, received: 0, sent: 0)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.sample() }
        ticker = timer; timer.resume(); publish()
    }
    private func sample() {
        guard snapshot.phase == .running else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let point = meter.sample(now: now, received: snapshot.received, sent: snapshot.sent)
        snapshot.receiveRate = point.received; snapshot.sendRate = point.sent
        snapshot.elapsed = max(0, now - (snapshot.startedUptime ?? now))
        snapshot.samples.append(point)
        if snapshot.samples.count > 60 { snapshot.samples.removeFirst(snapshot.samples.count - 60) }
        publish()
    }
    private func fail(_ reason: String) {
        generation += 1
        snapshot.phase = .failed; snapshot.configuration = nil; snapshot.error = reason
        snapshot.active = 0; snapshot.receiveRate = 0; snapshot.sendRate = 0
        snapshot.log(.error, reason)
        releaseResources { }; publish()
    }
    private func warning(_ text: String) {
        snapshot.error = text
        if snapshot.events.last?.text != text { snapshot.log(.warning, text) }
    }
    private func publish() { revision += 1; snapshot.revision = revision; observer?(snapshot) }
    private func releaseResources(completion: @escaping () -> Void) {
        ticker?.cancel(); ticker = nil; startTimeout?.cancel(); startTimeout = nil
        let old = Array(clients.values); clients.removeAll(); old.forEach { $0.close() }
        probes.values.forEach { $0.cancel() }; probes.removeAll()
        probePeers.values.forEach { $0.cancel() }; probePeers.removeAll()
        tokens.removeAll(); verified.removeAll()
        let pending = Array(listeners.values); listeners.removeAll()
        let group = DispatchGroup()
        for listener in pending {
            group.enter()
            var finished = false
            listener.newConnectionHandler = { $0.cancel() }
            listener.stateUpdateHandler = { state in
                if case .cancelled = state, !finished { finished = true; group.leave() }
            }
            listener.cancel()
        }
        group.notify(queue: queue, execute: completion)
    }
    private func remoteHost(_ connection: NWConnection) -> String {
        if case .hostPort(let host, _) = connection.endpoint { return "\(host)" }
        return ""
    }
    private func closed(_ relay: Relay) {
        if clients.removeValue(forKey: ObjectIdentifier(relay)) != nil { snapshot.active = max(0, snapshot.active - 1) }
    }

    private final class Relay {
        private enum Stage { case http, greeting, request, connecting, relay, closing }
        private weak var engine: ProxyEngine?
        private let client: NWConnection
        private let kind: ProxyKind
        private let generation: Int
        private var upstream: NWConnection?
        private var buffer = Data()
        private var stage: Stage
        private var closed = false
        private var clientEnded = false
        private var upstreamEnded = false
        private var tunnel = true
        private var deadline: DispatchWorkItem?
        init(engine: ProxyEngine, client: NWConnection, kind: ProxyKind, generation: Int) {
            self.engine = engine; self.client = client; self.kind = kind; self.generation = generation
            stage = kind == .http ? .http : .greeting
        }
        func start() {
            guard let engine else { return }
            client.stateUpdateHandler = { [weak self] state in
                if case .failed = state { self?.close() }
            }
            client.start(queue: engine.queue); armTimeout(10); receiveClient()
        }
        func close() {
            guard !closed else { return }; closed = true
            deadline?.cancel(); deadline = nil
            client.cancel(); upstream?.cancel(); engine?.closed(self)
        }
        private func armTimeout(_ seconds: Double) {
            deadline?.cancel()
            let task = DispatchWorkItem { [weak self] in self?.close() }
            deadline = task; engine?.queue.asyncAfter(deadline: .now() + seconds, execute: task)
        }
        private func receiveClient() {
            guard !closed, !clientEnded else { return }
            client.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
                guard let self, !self.closed else { return }
                guard error == nil else { self.close(); return }
                self.clientEnded = complete
                if self.stage == .relay {
                    self.forward(data ?? Data(), to: self.upstream, fromClient: true, ended: complete)
                } else {
                    self.buffer.append(data ?? Data())
                    self.process()
                }
            }
        }
        private func process() {
            guard !closed else { return }
            do {
                switch stage {
                case .greeting:
                    guard try ProxyCodec.greeting(&buffer) else { try more(); return }
                    stage = .request
                    client.send(content: Data([5, 0]), completion: .contentProcessed { [weak self] error in
                        guard let self else { return }; if error != nil { self.close() } else { self.process() }
                    })
                case .request:
                    guard let target = try ProxyCodec.socks(buffer) else { try more(); return }
                    buffer.removeAll(); connect(target)
                case .http:
                    guard let target = try ProxyCodec.http(buffer) else { try more(); return }
                    buffer.removeAll(); connect(target)
                default: break
                }
            } catch { reject(error) }
        }
        private func more() throws {
            if clientEnded { throw ProxyFailure.malformedHTTP }
            receiveClient()
        }
        private func connect(_ target: ProxyTarget) {
            guard let engine else { close(); return }
            if ProxyCodec.isLoop(host: target.host, port: target.port, localHosts: engine.localHosts,
                                 ports: engine.snapshot.configuration?.ports ?? []) { reject(ProxyFailure.proxyLoop); return }
            stage = .connecting; tunnel = target.tunnel
            let remote = NWConnection(host: NWEndpoint.Host(target.host), port: NWEndpoint.Port(rawValue: UInt16(target.port))!, using: .tcp)
            upstream = remote; armTimeout(10)
            remote.stateUpdateHandler = { [weak self, weak remote] state in
                guard let self, !self.closed else { return }
                switch state {
                case .ready:
                    guard self.stage == .connecting else { return }
                    if let engine = self.engine, case .hostPort(let host, let port)? = remote?.currentPath?.remoteEndpoint,
                       ProxyCodec.isLoop(host: "\(host)", port: Int(port.rawValue), localHosts: engine.localHosts,
                                         ports: engine.snapshot.configuration?.ports ?? []) { self.reject(ProxyFailure.proxyLoop); return }
                    self.connected(target)
                case .failed(let error): self.reject(error)
                default: break
                }
            }
            remote.start(queue: engine.queue)
        }
        private func connected(_ target: ProxyTarget) {
            let reply = kind == .socks5 ? ProxyCodec.socksReply(0) : target.tunnel ? Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8) : Data()
            let begin: () -> Void = { [weak self] in
                guard let self, !self.closed else { return }
                self.stage = .relay; self.armTimeout(120)
                self.receiveUpstream()
                self.forward(target.payload, to: self.upstream, fromClient: true, ended: self.clientEnded)
            }
            if reply.isEmpty { begin() }
            else { client.send(content: reply, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.close() } else { begin() }
            }) }
        }
        private func receiveUpstream() {
            guard !closed, !upstreamEnded else { return }
            upstream?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
                guard let self, !self.closed else { return }
                guard error == nil else { self.close(); return }
                self.upstreamEnded = complete
                self.forward(data ?? Data(), to: self.client, fromClient: false, ended: complete)
            }
        }
        // Read the next chunk only after the peer processed the previous write (bounded backpressure).
        private func forward(_ data: Data, to destination: NWConnection?, fromClient: Bool, ended: Bool) {
            guard let destination, !closed else { close(); return }
            let next: () -> Void = { [weak self] in
                guard let self, !self.closed else { return }
                if let engine = self.engine, engine.generation == self.generation {
                    if fromClient { engine.snapshot.sent += Int64(data.count) }
                    else { engine.snapshot.received += Int64(data.count) }
                }
                self.armTimeout(120)
                if ended {
                    destination.send(content: nil, contentContext: .finalMessage, isComplete: true,
                        completion: .contentProcessed { [weak self] _ in
                            guard let self else { return }
                            if self.clientEnded && self.upstreamEnded || !fromClient && !self.tunnel { self.close() }
                        })
                } else if fromClient { self.receiveClient() } else { self.receiveUpstream() }
            }
            if data.isEmpty { next() }
            else { destination.send(content: data, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.close() } else { next() }
            }) }
        }
        private func reject(_ error: Error) {
            guard !closed, stage != .closing else { return }
            if stage == .relay { engine?.warning(error.localizedDescription); close(); return }
            let greeting = stage == .greeting
            stage = .closing; armTimeout(2); engine?.warning(error.localizedDescription)
            let reply: Data
            if kind == .http {
                let status = error is ProxyFailure ? "400 Bad Request" : "502 Bad Gateway"
                reply = Data("HTTP/1.1 \(status)\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8)
            } else if greeting { reply = Data([5, 255]) }
            else { reply = ProxyCodec.socksReply(error as? ProxyFailure == .unsupportedCommand ? 7 : error as? ProxyFailure == .unsupportedAddress ? 8 : 1) }
            client.send(content: reply, completion: .contentProcessed { [weak self] _ in self?.close() })
        }
    }
}

import Foundation
import Darwin
import Network
import SwiftUI

@main
struct APSApp: App {
    @StateObject private var model = APSViewModel()

    var body: some Scene {
        WindowGroup { RootView(model: model) }
    }
}

@MainActor
final class APSViewModel: ObservableObject {
    @Published var settings = ProxySettings()
    @Published var runtime = RuntimeSnapshot()
    @Published var addresses: [String] = []
    @Published var selectedProtocol: ProxyProtocol = .http
    @Published var message: String?
    @Published var showRisk = false
    @Published var showPortEditor: ProxyProtocol?

    let server = ProxyServer()
    private var pathMonitor: NWPathMonitor?

    init() {
        server.onEvent = { [weak self] event in
            Task { @MainActor in self?.consume(event) }
        }
        refreshAddresses()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.refreshAddresses() }
        }
        monitor.start(queue: DispatchQueue(label: "com.ningso.aps.path"))
        pathMonitor = monitor
    }

    var host: String? { addresses.first }

    func start() {
        guard settings.hasProtocol, settings.validPorts, host != nil else {
            message = "Connect to trusted Wi‑Fi or enable a hotspot first."
            return
        }
        runtime.phase = .starting
        server.start(settings: settings) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.runtime.phase = .running
                    self?.runtime.config = self?.settings
                    self?.runtime.startedAt = Date()
                    self?.message = "Local listeners are ready in the foreground."
                case .failure(let error):
                    self?.runtime.phase = .failed
                    self?.runtime.lastError = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        runtime.phase = .stopping
        server.stop { [weak self] in
            Task { @MainActor in
                self?.runtime = RuntimeSnapshot()
            }
        }
    }

    func save(protocol kind: ProxyProtocol, port: Int, enabled: Bool) {
        let next = settings.with(protocol: kind, port: port, enabled: enabled)
        guard next.validPorts else { message = "Ports must be 1–65535 and different."; return }
        settings = next
        if runtime.running { server.reconfigure(settings: next) { _ in } }
        showPortEditor = nil
    }

    func configText(for kind: ProxyProtocol) -> String? {
        guard let host else { return nil }
        return "\(kind.rawValue) proxy\nHost: \(host)\nPort: \(settings.port(for: kind))\nAuthentication: none\nTrusted LAN only"
    }

    private func consume(_ event: ProxyServerEvent) {
        switch event {
        case .accepted: runtime.activeConnections += 1; runtime.totalConnections += 1
        case .closed: runtime.activeConnections = max(0, runtime.activeConnections - 1)
        case .bytesReceived(let count): runtime.bytesReceived += Int64(count)
        case .bytesSent(let count): runtime.bytesSent += Int64(count)
        case .failed(let text): runtime.lastError = text
        }
    }

    func refreshAddresses() {
        var result: [String] = []
        var cursor: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&cursor) == 0, let first = cursor else { return }
        defer { freeifaddrs(cursor) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let item = pointer {
            let flags = Int32(item.pointee.ifa_flags)
            let name = String(cString: item.pointee.ifa_name)
            if flags & IFF_UP != 0, let address = item.pointee.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET),
               let value = ipv4String(address),
               value != "127.0.0.1", !value.hasPrefix("169.254."),
               name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("ap") {
                result.append(value)
            }
            pointer = item.pointee.ifa_next
        }
        addresses = Array(Set(result)).sorted()
    }

    private func ipv4String(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var copy = address.pointee
        let result = withUnsafePointer(to: &copy) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            }
        }
        guard result == 0 else { return nil }
        return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

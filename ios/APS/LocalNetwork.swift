import Darwin
import Foundation

struct LocalAddress: Identifiable, Equatable, Sendable {
    let host: String
    let interface: String
    var id: String { interface + ":" + host }
}
enum LocalNetwork {
    static func addresses() -> [LocalAddress] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return [] }
        defer { freeifaddrs(first) }
        var output: [LocalAddress] = []; var cursor = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            let name = String(cString: entry.pointee.ifa_name)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("ap"),
                  let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var text = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &text, socklen_t(text.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let host = String(cString: text)
            guard host != "0.0.0.0", !host.hasPrefix("127."), !host.hasPrefix("169.254.") else { continue }
            output.append(LocalAddress(host: host, interface: name))
        }
        return output.sorted { $0.id < $1.id }
    }
}

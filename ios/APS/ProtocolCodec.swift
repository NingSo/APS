import Foundation

struct ProxyTarget: Equatable {
    let host: String
    let port: Int
    let tunnel: Bool
    let payload: Data
}

/// Pure incremental parsers. `nil` means more bytes are required; malformed complete frames throw.
/// Rebase Data after consuming a prefix: Foundation slices do not guarantee a zero startIndex.
enum ProxyCodec {
    static let maximumHeader = 32 * 1024
    static func http(_ input: Data) throws -> ProxyTarget? {
        let bytes = Data(input)
        guard let end = bytes.range(of: Data([13, 10, 13, 10])) else {
            if bytes.count > maximumHeader { throw ProxyFailure.headerTooLarge }
            return nil
        }
        guard end.upperBound <= maximumHeader else { throw ProxyFailure.headerTooLarge }
        let headerBytes = bytes[..<end.lowerBound]
        guard headerBytes.allSatisfy({ $0 == 9 || $0 == 10 || $0 == 13 || $0 >= 32 && $0 != 127 }),
              let header = String(data: headerBytes, encoding: .isoLatin1) else { throw ProxyFailure.malformedHTTP }
        let lines = header.components(separatedBy: "\r\n")
        let request = (lines.first ?? "").split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard request.count == 3, !request[0].isEmpty, request[0].utf8.allSatisfy(token),
              ["HTTP/1.0", "HTTP/1.1"].contains(request[2]) else { throw ProxyFailure.malformedHTTP }
        var fields: [(String, String)] = []
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":"), colon != line.startIndex else { throw ProxyFailure.malformedHTTP }
            let name = String(line[..<colon]); let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard name.utf8.allSatisfy(token), !value.contains("\r"), !value.contains("\n") else { throw ProxyFailure.malformedHTTP }
            fields.append((name, value))
        }
        let hosts = fields.filter { $0.0.lowercased() == "host" }
        let lengths = fields.filter { $0.0.lowercased() == "content-length" }
        let transfers = fields.filter { $0.0.lowercased() == "transfer-encoding" }
        guard hosts.count <= 1, lengths.count <= 1, transfers.count <= 1,
              lengths.isEmpty || transfers.isEmpty else { throw ProxyFailure.malformedHTTP }
        if let length = lengths.first?.1 {
            guard !length.isEmpty, length.utf8.allSatisfy({ (48...57).contains($0) }), UInt64(length) != nil else { throw ProxyFailure.malformedHTTP }
        }
        if let transfer = transfers.first?.1, transfer.lowercased() != "chunked" { throw ProxyFailure.malformedHTTP }
        let tail = Data(bytes[end.upperBound...])
        if request[0] == "CONNECT" {
            let destination = try authority(request[1], defaultPort: 443)
            return ProxyTarget(host: destination.0, port: destination.1, tunnel: true, payload: tail)
        }
        let host: String; let port: Int; let path: String
        if request[1].hasPrefix("/") {
            guard let authority = hosts.first?.1, !request[1].contains("#") else { throw ProxyFailure.malformedHTTP }
            (host, port) = try self.authority(authority, defaultPort: 80)
            path = request[1]
        } else {
            guard let url = URLComponents(string: request[1]), url.scheme?.lowercased() == "http",
                  let hostname = url.host, !hostname.isEmpty, url.user == nil, url.password == nil, url.fragment == nil else { throw ProxyFailure.malformedHTTP }
            host = normalizedHost(hostname); port = url.port ?? 80
            path = (url.percentEncodedPath.isEmpty ? "/" : url.percentEncodedPath) + (url.percentEncodedQuery.map { "?" + $0 } ?? "")
        }
        guard (1...65535).contains(port), validHost(host) else { throw ProxyFailure.malformedHTTP }
        let hopNames = Set(fields.filter { $0.0.lowercased() == "connection" }.flatMap {
            $0.1.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        })
        // Do not forward ambiguous framing nominated as hop-by-hop.
        guard hopNames.isDisjoint(with: ["content-length", "transfer-encoding", "host"]) else { throw ProxyFailure.malformedHTTP }
        let excluded = hopNames.union(["connection", "proxy-connection", "proxy-authorization", "keep-alive", "host"])
        let authorityHost = host.contains(":") ? "[\(host)]" : host
        var output = "\(request[0]) \(path) \(request[2])\r\nHost: \(authorityHost)\(port == 80 ? "" : ":\(port)")\r\n"
        for (name, value) in fields where !excluded.contains(name.lowercased()) { output += "\(name): \(value)\r\n" }
        output += "Connection: close\r\n\r\n"
        guard var payload = output.data(using: .isoLatin1) else { throw ProxyFailure.malformedHTTP }
        payload.append(tail)
        return ProxyTarget(host: host, port: port, tunnel: false, payload: payload)
    }
    static func authority(_ text: String, defaultPort: Int) throws -> (String, Int) {
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }),
              let value = URLComponents(string: "http://" + text), let hostname = value.host,
              value.user == nil, value.password == nil, value.path.isEmpty, value.query == nil, value.fragment == nil,
              !text.hasSuffix(":"), validHost(normalizedHost(hostname)),
              (1...65535).contains(value.port ?? defaultPort) else { throw ProxyFailure.malformedHTTP }
        return (normalizedHost(hostname), value.port ?? defaultPort)
    }
    static func greeting(_ input: inout Data) throws -> Bool {
        let b = Array(input)
        guard b.count >= 2 else { return false }
        guard b[0] == 5, b[1] > 0 else { throw ProxyFailure.invalidSOCKS }
        let count = Int(b[1]) + 2
        guard b.count >= count else { return false }
        guard b[2..<count].contains(0) else { throw ProxyFailure.noAuthentication }
        input = Data(b.dropFirst(count)); return true
    }
    static func socks(_ input: Data) throws -> ProxyTarget? {
        let b = Array(input)
        guard b.count >= 4 else { return nil }
        guard b[0] == 5, b[2] == 0 else { throw ProxyFailure.invalidSOCKS }
        guard b[1] == 1 else { throw ProxyFailure.unsupportedCommand }
        var offset = 4; let host: String
        switch b[3] {
        case 1:
            guard b.count >= 10 else { return nil }
            host = b[4..<8].map(String.init).joined(separator: "."); offset = 8
        case 3:
            guard b.count >= 5 else { return nil }
            let length = Int(b[4]); guard length > 0 else { throw ProxyFailure.invalidSOCKS }
            guard b.count >= 5 + length + 2 else { return nil }
            guard let name = String(bytes: b[5..<(5 + length)], encoding: .utf8), validHost(name) else { throw ProxyFailure.invalidSOCKS }
            host = name; offset = 5 + length
        case 4:
            guard b.count >= 22 else { return nil }
            host = stride(from: 4, to: 20, by: 2).map { String(UInt16(b[$0]) << 8 | UInt16(b[$0 + 1]), radix: 16) }.joined(separator: ":")
            offset = 20
        default: throw ProxyFailure.unsupportedAddress
        }
        let port = Int(b[offset]) << 8 | Int(b[offset + 1])
        guard port > 0 else { throw ProxyFailure.invalidSOCKS }
        return ProxyTarget(host: host, port: port, tunnel: true, payload: Data(b.dropFirst(offset + 2)))
    }
    static func socksReply(_ status: UInt8) -> Data { Data([5, status, 0, 1, 0, 0, 0, 0, 0, 0]) }
    static func isLoop(host: String, port: Int, localHosts: Set<String>, ports: Set<Int>) -> Bool {
        let host = normalizedHost(host).lowercased()
        return ports.contains(port) && (host == "localhost" || host == "::1" || host == "0.0.0.0" || host.hasPrefix("127.") || localHosts.contains(host))
    }
    private static func normalizedHost(_ text: String) -> String {
        text.hasPrefix("[") && text.hasSuffix("]") ? String(text.dropFirst().dropLast()) : text
    }
    private static func validHost(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { $0 > 32 && $0 < 127 && ![47, 92, 64, 35, 63].contains($0) }
    }
    private static func token(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || Array("!#$%&'*+-.^_`|~".utf8).contains(byte)
    }
}

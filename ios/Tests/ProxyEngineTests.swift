import Darwin
import Foundation
import Network
import XCTest
@testable import APS

final class ProxyEngineTests:XCTestCase {
    private var engine:ProxyEngine!
    override func setUp() { super.setUp(); engine = ProxyEngine(allowLocalTestClients:true) }
    override func tearDown() { engine.stop(); engine = nil; super.tearDown() }

    private func start(_ supplied:Preferences? = nil) throws -> Preferences {
        var settings = supplied ?? Preferences()
        if supplied == nil {
            settings.httpPort = try unusedPort()
            repeat { settings.socksPort = try unusedPort() } while settings.socksPort == settings.httpPort
        }
        let ready = SnapshotGate { $0.phase == .running }
        engine.observe(ready.accept)
        engine.start(settings,localHosts:["127.0.0.1"])
        XCTAssertEqual(XCTWaiter.wait(for:[ready.expectation],timeout:15),.completed)
        XCTAssertEqual(ready.value?.active,0); XCTAssertEqual(ready.value?.total,0)
        return settings
    }
    func testHTTPForward() throws {
        let peer = try LocalPeer(http:true); defer { peer.stop() }
        let settings = try start()
        let client = try TestSocket(port:settings.httpPort)
        try client.send(Data("GET http://127.0.0.1:\(peer.port)/probe HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8))
        let response = try client.readToEnd()
        XCTAssertTrue(String(decoding:response,as:UTF8.self).hasSuffix("\r\n\r\nHELLO"))
        let counted = SnapshotGate { $0.received > 0 && $0.sent > 0 }
        engine.observe(counted.accept)
        XCTAssertEqual(XCTWaiter.wait(for:[counted.expectation],timeout:3),.completed)
    }
    func testCONNECTPreservesEarlyPayload() throws {
        let peer = try LocalPeer(); defer { peer.stop() }
        let settings = try start()
        let client = try TestSocket(port:settings.httpPort)
        let payload = Data((0..<8192).map { UInt8($0 % 251) })
        var request = Data("CONNECT 127.0.0.1:\(peer.port) HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8)
        request.append(payload); try client.send(request)
        XCTAssertTrue(try client.readHeader().contains("200 Connection Established"))
        XCTAssertEqual(try client.readExactly(payload.count),payload)
    }
    func testFragmentedSOCKSAndEarlyPayload() throws {
        let peer = try LocalPeer(); defer { peer.stop() }
        let settings = try start()
        let client = try TestSocket(port:settings.socksPort)
        try client.send(Data([5])); Thread.sleep(forTimeInterval:0.05)
        try client.send(Data([1,0])); XCTAssertEqual(try client.readExactly(2),Data([5,0]))
        var request = Data([5,1,0,1,127,0,0,1,UInt8(peer.port >> 8),UInt8(peer.port & 255)])
        request.append(Data("ping".utf8)); try client.send(request)
        XCTAssertEqual(try client.readExactly(10).prefix(2),Data([5,0]))
        XCTAssertEqual(try client.readExactly(4),Data("ping".utf8))
    }
    func testSOCKSRejectsUDPWithReplyBeforeClosing() throws {
        let settings = try start()
        let client = try TestSocket(port:settings.socksPort)
        try client.send(Data([5,1,0])); _ = try client.readExactly(2)
        try client.send(Data([5,3,0,1,127,0,0,1,0,80]))
        XCTAssertEqual(try client.readExactly(10)[1],7)
    }
    func testMalformedHTTPGets400() throws {
        let settings = try start()
        let client = try TestSocket(port:settings.httpPort)
        try client.send(Data("GET / HTTP/1.1\r\n\r\n".utf8))
        XCTAssertTrue(try client.readHeader().contains("400 Bad Request"))
    }
    func testHalfCloseStillDrainsReply() throws {
        let peer = try LocalPeer(); defer { peer.stop() }
        let settings = try start()
        let client = try TestSocket(port:settings.httpPort)
        try client.send(Data("CONNECT 127.0.0.1:\(peer.port) HTTP/1.1\r\n\r\n".utf8))
        _ = try client.readHeader()
        let bytes = Data(repeating:42,count:131072)
        try client.send(bytes); client.finishWriting()
        XCTAssertEqual(try client.readToEnd(),bytes)
    }
    func testOccupiedPortFailsWithoutPartialListeners() throws {
        let peer = try LocalPeer(); defer { peer.stop() }
        var settings = Preferences(); settings.httpPort = peer.port; settings.socksPort = try unusedPort()
        let failed = SnapshotGate { $0.phase == .failed }
        engine.observe(failed.accept); engine.start(settings,localHosts:[])
        XCTAssertEqual(XCTWaiter.wait(for:[failed.expectation],timeout:15),.completed)
        XCTAssertNil(failed.value?.configuration)
    }
    func testNoProtocolFails() {
        var settings = Preferences(); settings.httpEnabled = false; settings.socksEnabled = false
        let failed = SnapshotGate { $0.phase == .failed }
        engine.observe(failed.accept); engine.start(settings,localHosts:[])
        XCTAssertEqual(XCTWaiter.wait(for:[failed.expectation],timeout:3),.completed)
    }
    func testReconfigurationAndStop() throws {
        let settings = try start()
        var next = settings
        repeat { next.httpPort = try unusedPort() } while next.httpPort == settings.httpPort || next.httpPort == settings.socksPort
        let expected = next.httpPort
        let changed = SnapshotGate { $0.phase == .running && $0.configuration?.httpPort == expected }
        engine.observe(changed.accept); engine.reconfigure(next,localHosts:["127.0.0.1"])
        XCTAssertEqual(XCTWaiter.wait(for:[changed.expectation],timeout:15),.completed)
        XCTAssertThrowsError(try TestSocket(port:settings.httpPort))
        let stopped = SnapshotGate { $0.phase == .stopped }
        engine.observe(stopped.accept); engine.stop()
        XCTAssertEqual(XCTWaiter.wait(for:[stopped.expectation],timeout:5),.completed)
        XCTAssertEqual(stopped.value?.total,0); XCTAssertEqual(stopped.value?.events.count,0)
    }
}

private final class SnapshotGate:@unchecked Sendable {
    let expectation = XCTestExpectation(description:"engine state")
    private let lock = NSLock()
    private let match:(SessionSnapshot)->Bool
    private var stored:SessionSnapshot?
    init(_ match:@escaping (SessionSnapshot)->Bool) { self.match = match }
    var value:SessionSnapshot? { lock.lock(); defer { lock.unlock() }; return stored }
    func accept(_ snapshot:SessionSnapshot) {
        lock.lock(); defer { lock.unlock() }
        if stored == nil && match(snapshot) { stored = snapshot; expectation.fulfill() }
    }
}
private enum TestFailure:Error { case socket, timeout, unexpectedEOF, tooMuchData }
private func unusedPort() throws -> Int {
    let fd = Darwin.socket(AF_INET,SOCK_STREAM,0); guard fd >= 0 else { throw TestFailure.socket }
    defer { Darwin.close(fd) }
    var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bound = withUnsafePointer(to:&address) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    guard bound == 0 else { throw TestFailure.socket }
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let result = withUnsafeMutablePointer(to:&address) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { getsockname(fd,$0,&length) } }
    guard result == 0 else { throw TestFailure.socket }
    return Int(UInt16(bigEndian:address.sin_port))
}
private final class TestSocket {
    private let fd:Int32
    init(port:Int) throws {
        fd = Darwin.socket(AF_INET,SOCK_STREAM,0)
        guard fd >= 0 else { throw TestFailure.socket }
        var timeout = timeval(tv_sec:5,tv_usec:0)
        setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,socklen_t(MemoryLayout<timeval>.size))
        var yes:Int32 = 1; setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian; address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to:&address) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.connect(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard result == 0 else { Darwin.close(fd); throw TestFailure.socket }
    }
    deinit { Darwin.close(fd) }
    func send(_ data:Data) throws {
        try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.send(fd,base.advanced(by:offset),buffer.count-offset,0)
                guard count > 0 else { throw TestFailure.socket }; offset += count
            }
        }
    }
    func finishWriting() { shutdown(fd,SHUT_WR) }
    private func read(_ maximum:Int) throws -> Data {
        var buffer = [UInt8](repeating:0,count:maximum)
        let count = Darwin.recv(fd,&buffer,maximum,0)
        guard count >= 0 else { throw TestFailure.timeout }
        return Data(buffer.prefix(count))
    }
    func readExactly(_ count:Int) throws -> Data {
        var result = Data()
        while result.count < count {
            let next = try read(min(count-result.count,65536)); guard !next.isEmpty else { throw TestFailure.unexpectedEOF }; result.append(next)
        }; return result
    }
    func readHeader() throws -> String {
        var data = Data()
        while data.count < 32768 {
            data.append(try readExactly(1))
            if data.suffix(4) == Data([13,10,13,10]) { return String(decoding:data,as:UTF8.self) }
        }; throw TestFailure.tooMuchData
    }
    func readToEnd() throws -> Data {
        var data = Data()
        while data.count < 1048576 {
            let next = try read(65536); if next.isEmpty { return data }; data.append(next)
        }; throw TestFailure.tooMuchData
    }
}
private final class LocalPeer:@unchecked Sendable {
    private let queue = DispatchQueue(label:"aps.test.peer")
    private let listener:NWListener
    private var clients:[NWConnection] = []
    private let http:Bool
    var port:Int { Int(listener.port!.rawValue) }
    init(http:Bool = false) throws {
        self.http = http; listener = try NWListener(using:.tcp,on:.any)
        let ready = XCTestExpectation(description:"local peer")
        listener.stateUpdateHandler = { state in if case .ready = state { ready.fulfill() } }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.clients.append(connection); connection.start(queue:self.queue)
            if self.http { self.readHTTP(connection,buffer:Data()) } else { self.echo(connection) }
        }
        listener.start(queue:queue)
        guard XCTWaiter.wait(for:[ready],timeout:5) == .completed else { throw TestFailure.timeout }
    }
    func stop() { queue.sync { listener.cancel(); clients.forEach { $0.cancel() }; clients.removeAll() } }
    private func readHTTP(_ connection:NWConnection,buffer:Data) {
        connection.receive(minimumIncompleteLength:1,maximumLength:32768) { [weak self] data,_,done,error in
            guard let self = self, error == nil else { connection.cancel(); return }
            var next = buffer; next.append(data ?? Data())
            if next.range(of:Data([13,10,13,10])) != nil {
                connection.send(content:Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nHELLO".utf8),contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { _ in connection.cancel() })
            } else if done || next.count > 32768 { connection.cancel() }
            else { self.readHTTP(connection,buffer:next) }
        }
    }
    private func echo(_ connection:NWConnection) {
        connection.receive(minimumIncompleteLength:1,maximumLength:65536) { [weak self] data,_,done,error in
            guard let self = self, error == nil else { connection.cancel(); return }
            connection.send(content:data,contentContext:done ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [weak self] error in
                if done || error != nil { connection.cancel() } else { self?.echo(connection) }
            })
        }
    }
}

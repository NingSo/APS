import XCTest
@testable import APS

final class ProtocolCodecTests:XCTestCase {
    func testHTTPFragmentWaits() throws {
        XCTAssertNil(try ProxyCodec.http(Data("GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n".utf8)))
    }
    func testAbsoluteRequestRewritesTargetAndPreservesBody() throws {
        let data = Data("POST http://example.com:8081/a?q=1 HTTP/1.1\r\nHost: wrong.example\r\nContent-Length: 3\r\nProxy-Connection: keep-alive\r\n\r\nabc".utf8)
        let target = try XCTUnwrap(ProxyCodec.http(data))
        XCTAssertEqual(target.host,"example.com"); XCTAssertEqual(target.port,8081); XCTAssertFalse(target.tunnel)
        let payload = String(decoding:target.payload,as:UTF8.self)
        XCTAssertTrue(payload.hasPrefix("POST /a?q=1 HTTP/1.1\r\nHost: example.com:8081"))
        XCTAssertFalse(payload.contains("Proxy-Connection")); XCTAssertTrue(payload.hasSuffix("\r\n\r\nabc"))
    }
    func testRelativeRequestUsesHostPort() throws {
        let target = try XCTUnwrap(ProxyCodec.http(Data("GET /a HTTP/1.1\r\nHost: example.com:8081\r\n\r\n".utf8)))
        XCTAssertEqual(target.host,"example.com"); XCTAssertEqual(target.port,8081)
    }
    func testConnectIPv6AndEarlyPayload() throws {
        var data = Data("CONNECT [2001:db8::1]:443 HTTP/1.1\r\nHost: [2001:db8::1]\r\n\r\n".utf8)
        data.append(contentsOf:[22,3,1,0,0])
        let target = try XCTUnwrap(ProxyCodec.http(data))
        XCTAssertEqual(target.host,"2001:db8::1"); XCTAssertEqual(target.port,443)
        XCTAssertTrue(target.tunnel); XCTAssertEqual(target.payload,Data([22,3,1,0,0]))
    }
    func testRejectHTTPSAbsoluteForm() {
        XCTAssertThrowsError(try ProxyCodec.http(Data("GET https://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8)))
    }
    func testRejectHeaderInjectionAndAmbiguousFraming() {
        for fields in ["Host: a\r\nHost: b", "Host: a\r\nContent-Length: 1\r\nContent-Length: 2", "Host: a\r\nContent-Length: 1\r\nTransfer-Encoding: chunked", "Host: a\r\nContent-Length: -1", "Host: a\r\nConnection: content-length", " Host: a"] {
            XCTAssertThrowsError(try ProxyCodec.http(Data(("GET / HTTP/1.1\r\n"+fields+"\r\n\r\n").utf8)))
        }
    }
    func testHeaderSizeLimit() {
        XCTAssertThrowsError(try ProxyCodec.http(Data(repeating:65,count:ProxyCodec.maximumHeader+1)))
    }
    func testAuthorityValidation() throws {
        XCTAssertEqual(try ProxyCodec.authority("[::1]:8080",defaultPort:80).1,8080)
        for value in ["example.com:","example.com:0","example.com:65536","user@example.com","example.com/a","a b"] {
            XCTAssertThrowsError(try ProxyCodec.authority(value,defaultPort:80),value)
        }
    }
    func testFragmentedGreeting() throws {
        var data = Data([5]); XCTAssertFalse(try ProxyCodec.greeting(&data))
        data.append(1); XCTAssertFalse(try ProxyCodec.greeting(&data))
        data.append(0); XCTAssertTrue(try ProxyCodec.greeting(&data)); XCTAssertTrue(data.isEmpty)
    }
    func testGreetingConsumesOnlyItsFrame() throws {
        var data = Data([5,1,0,5,1,0,1,127,0,0,1,0,80])
        XCTAssertTrue(try ProxyCodec.greeting(&data))
        XCTAssertEqual(try ProxyCodec.socks(data)?.port,80)
    }
    func testRejectUnsupportedAuthentication() {
        var data = Data([5,1,2]); XCTAssertThrowsError(try ProxyCodec.greeting(&data))
    }
    func testSOCKSDomainAndTail() throws {
        var data = Data([5,1,0,3,11]); data.append(Data("example.com".utf8)); data.append(contentsOf:[1,187,7,8,9])
        let target = try XCTUnwrap(ProxyCodec.socks(data))
        XCTAssertEqual(target.host,"example.com"); XCTAssertEqual(target.port,443); XCTAssertEqual(target.payload,Data([7,8,9]))
    }
    func testSOCKSIPv6() throws {
        let packet = Data([5,1,0,4]+[UInt8](repeating:0,count:15)+[1,1,187])
        let target = try XCTUnwrap(ProxyCodec.socks(packet))
        XCTAssertEqual(target.host,"0:0:0:0:0:0:0:1"); XCTAssertEqual(target.port,443)
    }
    func testSOCKSFragmentedRequest() throws {
        let packet = Data([5,1,0,1,192,0,2,1,1,187])
        for i in 0..<packet.count { XCTAssertNil(try ProxyCodec.socks(Data(packet.prefix(i)))) }
        XCTAssertNotNil(try ProxyCodec.socks(packet))
    }
    func testRejectUnsupportedCommandsAndZeroPort() {
        for packet:[UInt8] in [[5,2,0,1],[5,3,0,1],[5,1,1,1],[5,1,0,99],[5,1,0,1,127,0,0,1,0,0]] {
            XCTAssertThrowsError(try ProxyCodec.socks(Data(packet)))
        }
    }
    func testLoopGuard() {
        XCTAssertTrue(ProxyCodec.isLoop(host:"localhost",port:8080,localHosts:[],ports:[8080]))
        XCTAssertTrue(ProxyCodec.isLoop(host:"192.0.2.10",port:1080,localHosts:["192.0.2.10"],ports:[1080]))
        XCTAssertFalse(ProxyCodec.isLoop(host:"127.0.0.1",port:8001,localHosts:[],ports:[8080]))
    }
}

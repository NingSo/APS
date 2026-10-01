import XCTest
@testable import APS

final class DomainTests:XCTestCase {
    func testDefaultConfiguration() {
        let p = Preferences()
        XCTAssertTrue(p.valid); XCTAssertTrue(p.hasProtocol)
        XCTAssertEqual(p.ports,Set([8080,1080]))
    }
    func testInvalidPortInputs() {
        for value in ["","0","65536","-1"," 80","80 ","a","1.5","999999999999999999999"] {
            XCTAssertNotNil(Preferences.portError(value,other:1080),value)
        }
        XCTAssertNil(Preferences.portError("65535",other:1080))
    }
    func testPortCollisionEvenWhileDisabled() {
        XCTAssertNotNil(Preferences.portError("1080",other:1080))
        let p = Preferences().editing(.http,port:1080,enabled:false)
        XCTAssertFalse(p.valid)
    }
    func testEditingPreservesOtherProtocol() {
        let p = Preferences().editing(.http,port:8090,enabled:false)
        XCTAssertEqual(p.httpPort,8090); XCTAssertFalse(p.httpEnabled)
        XCTAssertEqual(p.socksPort,1080); XCTAssertTrue(p.socksEnabled)
    }
    func testPreferencesCodableRoundTrip() throws {
        var p = Preferences(); p.reduceMotion = true; p.keepAwake = true
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(p)),p)
    }
    func testByteUnits() {
        XCTAssertEqual(ByteAmount(1024).value,"1.0")
        XCTAssertEqual(ByteAmount(1024,rate:true).unit,"KiB/s")
        XCTAssertEqual(ByteAmount(-1).value,"0")
        XCTAssertEqual(ByteAmount(1048576).unit,"MiB")
    }
    func testMonotonicRateAndCounterReset() {
        var meter = RateMeter()
        XCTAssertEqual(meter.sample(now:10,received:0,sent:0).received,0)
        let rate = meter.sample(now:12,received:2048,sent:1024)
        XCTAssertEqual(rate.received,1024); XCTAssertEqual(rate.sent,512)
        XCTAssertEqual(meter.sample(now:13,received:0,sent:0).received,0)
        XCTAssertEqual(meter.sample(now:13,received:10,sent:10).received,0)
    }
    func testBoundedLogsAndIdentity() {
        var state = SessionSnapshot()
        for i in 0..<500 { state.log(.info,"event \(i)") }
        XCTAssertEqual(state.events.count,200)
        XCTAssertEqual(state.events.last?.id,500)
        XCTAssertEqual(Set(state.events.map(\.id)).count,200)
    }
    func testSelectedDoesNotMeanListening() {
        let prefs = Preferences()
        var state = SessionSnapshot()
        state.configuration = prefs
        XCTAssertFalse(state.listening(.http,preferences:prefs))
        state.phase = .running
        XCTAssertTrue(state.listening(.http,preferences:prefs))
        XCTAssertFalse(state.listening(.http,preferences:prefs.editing(.http,port:8090,enabled:true)))
    }
    func testShareAndCommandUseCurrentConfiguration() {
        let p = Preferences().editing(.socks5,port:1081,enabled:true)
        let text = configurationText(host:"192.0.2.10",preferences:p,kind:.socks5)
        XCTAssertTrue(text.contains("Port: 1081")); XCTAssertTrue(text.contains("Authentication: none"))
        XCTAssertTrue(clientCommand(host:"192.0.2.10",preferences:p,kind:.socks5).contains("socks5h://192.0.2.10:1081"))
        XCTAssertEqual(sessionDuration(754),"00:12:34")
    }
}

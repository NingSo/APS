import XCTest
@testable import APS

final class ProtocolModelsTests: XCTestCase {
    func testDefaultPortsAndValidation() {
        let settings = ProxySettings()
        XCTAssertEqual(settings.httpPort, 8080)
        XCTAssertEqual(settings.socksPort, 1080)
        XCTAssertTrue(settings.validPorts)
        XCTAssertFalse(settings.with(protocol: .http, port: settings.socksPort, enabled: true).validPorts)
    }

    func testDisabledProtocolsMaySharePort() {
        let settings = ProxySettings(httpEnabled: false, httpPort: 1080, socksPort: 1080)
        XCTAssertTrue(settings.validPorts)
    }
}

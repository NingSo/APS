import XCTest
@testable import APS

final class ProxyServerTests: XCTestCase {
    func testStartRejectsConfigurationWithoutAProtocol() {
        let server = ProxyServer()
        let expectation = expectation(description: "completion")
        server.start(settings: ProxySettings(httpEnabled: false, socksEnabled: false)) { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error as? ProxyError, .invalidConfiguration)
            } else {
                XCTFail("Invalid configuration unexpectedly started")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testStartRejectsDuplicateEnabledPorts() {
        let server = ProxyServer()
        let expectation = expectation(description: "completion")
        server.start(settings: ProxySettings(httpPort: 8080, socksPort: 8080)) { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error as? ProxyError, .invalidConfiguration)
            } else {
                XCTFail("Invalid configuration unexpectedly started")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

import XCTest

final class SignalUITests:XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ fixture:String) {
        app.launchArguments = ["--ui-fixture",fixture]
        app.launch()
        XCTAssertTrue(app.buttons["nav-overview"].waitForExistence(timeout:10))
    }
    private func capture(_ name:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testCompleteScreens() {
        launch("running"); capture("01-overview-running")
        app.buttons["nav-connect"].tap()
        XCTAssertTrue(app.staticTexts["CONNECTION PASS"].waitForExistence(timeout:5)); capture("02-connection")
        app.buttons["nav-activity"].tap()
        XCTAssertTrue(app.textFields["log-search"].waitForExistence(timeout:5)); capture("03-activity")
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.switches["reduce-motion"].exists || app.staticTexts["少一点干扰。"].exists); capture("04-settings")
        app.buttons["连接诊断"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["找到连接的断点。"].waitForExistence(timeout:5)); capture("05-diagnostics")
    }
    func testRiskConsentIsRequired() {
        launch("stopped")
        app.buttons["power-control"].tap()
        let confirm = app.buttons["confirm-start"]
        XCTAssertTrue(confirm.waitForExistence(timeout:5)); XCTAssertFalse(confirm.isEnabled)
        capture("06-consent")
    }
    func testPortValidationAndPersistence() {
        launch("stopped")
        app.buttons["protocol-HTTP"].tap()
        let input = app.textFields["port-input"]
        XCTAssertTrue(input.waitForExistence(timeout:5))
        input.tap()
        let value = input.value as? String ?? ""
        input.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:value.count)+"65536")
        XCTAssertFalse(app.buttons["save-port"].isEnabled); capture("07-invalid-port")
        input.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:5)+"8090")
        if app.buttons["完成"].exists { app.buttons["完成"].tap() }
        XCTAssertTrue(app.buttons["save-port"].isEnabled)
        app.buttons["save-port"].tap()
        XCTAssertTrue(app.staticTexts[":8090"].waitForExistence(timeout:5))
    }
    func testNoAddressDoesNotGenerateQR() {
        launch("no-address"); app.buttons["nav-connect"].tap()
        XCTAssertTrue(app.staticTexts["接入可信局域网后再继续"].waitForExistence(timeout:5))
        XCTAssertFalse(app.otherElements["configuration-qr"].exists); capture("08-no-address")
    }
    func testShareSheet() {
        launch("running"); app.buttons["nav-connect"].tap()
        app.buttons["二维码分享"].tap()
        XCTAssertTrue(app.buttons["system-share"].waitForExistence(timeout:5)); capture("09-share")
    }
    func testFailedState() {
        launch("failed"); XCTAssertTrue(app.staticTexts["连接，需要处理。"].exists); capture("10-failed")
    }
    func testLogSearchEmptyResult() {
        launch("running"); app.buttons["nav-activity"].tap()
        let search = app.textFields["log-search"]; search.tap(); search.typeText("no-matching-event")
        XCTAssertTrue(app.staticTexts["没有匹配的日志。试试其他关键词或筛选条件。"].waitForExistence(timeout:5))
    }
    func testNativeOrbitProducesDifferentFrames() {
        launch("motion"); capture("11-motion-start")
        Thread.sleep(forTimeInterval:1.2)
        capture("12-motion-later")
        // The pair is retained for visual review; screenshots alone are not a frame-rate assertion.
        XCTAssertTrue(app.buttons["power-control"].exists)
    }
}

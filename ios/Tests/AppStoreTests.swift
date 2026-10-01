import XCTest
import CoreImage
@testable import APS

final class AppStoreTests:XCTestCase {
    @MainActor func testPreferencesPersistWithoutAutoStart() {
        let name = "aps.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let first = AppStore(defaults:defaults,monitorNetwork:false)
        first.setReduceMotion(true)
        XCTAssertTrue(first.save(.http,text:"8090",enabled:true))
        let second = AppStore(defaults:defaults,monitorNetwork:false)
        XCTAssertEqual(second.preferences.httpPort,8090)
        XCTAssertTrue(second.preferences.reduceMotion)
        XCTAssertEqual(second.session.phase,.stopped)
    }
    @MainActor func testInvalidEditDoesNotChangePreferences() {
        let model = AppStore(monitorNetwork:false)
        let before = model.preferences
        XCTAssertFalse(model.save(.http,text:"not-a-port",enabled:true))
        XCTAssertEqual(model.preferences,before)
    }
    @MainActor func testNavigationUsesThreeTabsWithSecondarySettings() {
        let model = AppStore(monitorNetwork:false)
        model.navigate(.connect); model.navigate(.settings)
        XCTAssertEqual(model.selectedTab,.connect)
        model.back(); XCTAssertEqual(model.page,.connect)
    }
    @MainActor func testMissingNetworkDoesNotStart() {
        let model = AppStore(monitorNetwork:false)
        model.confirmStart(host:"192.0.2.10",revision:-1)
        XCTAssertEqual(model.session.phase,.stopped)
    }
    func testQRDecodesCurrentConfiguration() throws {
        let payload = configurationText(host:"192.0.2.10",preferences:Preferences(),kind:.http)
        let image = try XCTUnwrap(ConfigurationQR.image(payload))
        let ciImage = try XCTUnwrap(CIImage(image:image))
        let detector = try XCTUnwrap(CIDetector(ofType:CIDetectorTypeQRCode,context:nil,options:[CIDetectorAccuracy:CIDetectorAccuracyHigh]))
        let feature = try XCTUnwrap(detector.features(in:ciImage).first as? CIQRCodeFeature)
        XCTAssertEqual(feature.messageString,payload)
    }
}

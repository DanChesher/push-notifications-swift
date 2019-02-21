import XCTest
@testable import PushNotifications

class SDKTests: XCTestCase {
    func testVersionModel() {
        let version = SDK.version
        XCTAssertNotNil(version)
        XCTAssertEqual(version, "1.2.1")
    }
}

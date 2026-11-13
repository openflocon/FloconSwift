import Foundation
import Testing
@testable import Flocon

struct FloconBonjourBodyTests {
    private func decode(_ body: FloconBonjourBody) throws -> [String: String] {
        let json = try #require(body.json())
        return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
    }

    @Test func defaultConnectionIsSent() throws {
        #expect(try decode(FloconBonjourBody(connectionType: .default))["connectionType"] == "default")
    }

    @Test func wifiConnectionIsSent() throws {
        #expect(try decode(FloconBonjourBody(connectionType: .wifi))["connectionType"] == "wifi")
    }

    @Test func sdkIsSwift() throws {
        #expect(try decode(FloconBonjourBody(connectionType: .default))["sdk"] == "swift")
    }
}

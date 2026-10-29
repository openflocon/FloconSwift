import Testing
@testable import Flocon

struct FloconBonjourBodyTests {
    @Test func defaultConnectionIsSent() {
        #expect(FloconBonjourBody(connectionType: .default).json() == #"{"connectionType":"default"}"#)
    }

    @Test func wifiConnectionIsSent() {
        #expect(FloconBonjourBody(connectionType: .wifi).json() == #"{"connectionType":"wifi"}"#)
    }
}

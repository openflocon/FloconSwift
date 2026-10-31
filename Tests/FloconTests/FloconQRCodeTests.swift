import Testing
@testable import Flocon

struct FloconQRCodeTests {
    @Test func plainAddressIsKept() {
        #expect(floconAddress(fromQRCode: "192.168.1.20") == "192.168.1.20")
    }

    @Test func whitespaceAroundTheAddressIsRemoved() {
        #expect(floconAddress(fromQRCode: " my-mac.local\n") == "my-mac.local")
    }

    @Test func urlGivesItsHost() {
        #expect(floconAddress(fromQRCode: "flocon://192.168.1.20") == "192.168.1.20")
        #expect(floconAddress(fromQRCode: "wss://my-mac.local:9023/path?token=1") == "my-mac.local")
    }

    @Test func textThatIsNotAnAddressIsKeptSoItIsReportedAsInvalid() {
        #expect(floconAddress(fromQRCode: "hello world") == "hello world")
        #expect(floconAddress(fromQRCode: "://") == "://")
    }
}

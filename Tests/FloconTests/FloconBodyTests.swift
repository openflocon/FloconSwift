import Foundation
import Testing
@testable import Flocon

@Suite struct FloconBodyTests {
    // MARK: FloconBody

    @Test func keepsTheWholeBody() {
        var body = FloconBody()
        body.append(Data("hello ".utf8))
        body.append(Data(String(repeating: "x", count: 2 * 1024 * 1024).utf8))

        #expect(body.totalSize == 6 + 2 * 1024 * 1024)
        #expect(body.data.count == 6 + 2 * 1024 * 1024)
        #expect(body.text?.hasPrefix("hello x") == true)
    }

    @Test func countsWithoutKeeping() {
        var body = FloconBody()
        body.count(9_244)

        #expect(body.totalSize == 9_244)
        #expect(body.data.isEmpty)
    }

    @Test func binaryIsNotText() {
        let body = FloconBody(data: Data([0xFF, 0xFE, 0xFD]))

        #expect(body.text == nil)
    }

    // MARK: Request body

    @Test func readsAWholeStream() {
        let content = Data(String(repeating: "y", count: 200_000).utf8)
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.httpBodyStream = InputStream(data: content)

        #expect(FloconURLProtocol.readBody(of: request) == content)
    }

    // MARK: Logger

    @Test func truncatesLongPayloads() {
        let long = String(repeating: "x", count: FloconLogger.maxPayloadLength + 10)

        let truncated = FloconLogger.truncated(long)

        #expect(truncated.hasPrefix(String(repeating: "x", count: FloconLogger.maxPayloadLength) + "…"))
        #expect(truncated.hasSuffix("(\(long.utf8.count) bytes)"))
        #expect(FloconLogger.truncated("short") == "short")
    }
}

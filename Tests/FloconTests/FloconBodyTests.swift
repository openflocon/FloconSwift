import Foundation
import Testing
@testable import Flocon

@Suite struct FloconBodyTests {
    // MARK: FloconCappedBody

    @Test func keepsAShortBodyAsIs() {
        var body = FloconCappedBody(limit: 10)
        body.append(Data("hello".utf8))

        #expect(!body.isTruncated)
        #expect(body.totalSize == 5)
        #expect(body.text == "hello")
    }

    @Test func keepsOnlyTheLimitButCountsEverything() {
        var body = FloconCappedBody(limit: 4)
        body.append(Data("abc".utf8))
        body.append(Data("defgh".utf8))

        #expect(body.data == Data("abcd".utf8))
        #expect(body.totalSize == 8)
        #expect(body.isTruncated)
        #expect(body.text?.hasPrefix("abcd\n… [truncated by Flocon: 8 bytes in total]") == true)
    }

    @Test func doesNotCutAUTF8Character() {
        // "é" is 2 bytes: a limit of 2 cuts it after "a"
        let body = FloconCappedBody(limit: 2, data: Data("aé".utf8))

        #expect(body.isTruncated)
        #expect(body.text?.hasPrefix("a\n…") == true)
    }

    @Test func countsWithoutKeeping() {
        var body = FloconCappedBody(limit: 100)
        body.count(1_000)

        #expect(body.data.isEmpty)
        #expect(body.totalSize == 1_000)
    }

    @Test func binaryIsNotText() {
        let body = FloconCappedBody(limit: 100, data: Data([0xFF, 0xFE, 0xFD]))

        #expect(body.text == nil)
    }

    // MARK: FloconRequestBody

    @Test func logsTheBodyOfARequestWithoutTouchingIt() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.httpBody = Data("0123456789".utf8)

        let body = FloconRequestBody.read(from: request, limit: 4)

        #expect(body.forwarded == nil)
        #expect(body.logged?.data == Data("0123".utf8))
        #expect(body.logged?.totalSize == 10)
    }

    @Test func keepsAShortStreamInMemory() throws {
        let stream = InputStream(data: Data("short".utf8))

        let body = FloconRequestBody.read(stream: stream, limit: 100, temporaryDirectory: FileManager.default.temporaryDirectory)

        guard case .data(let data) = body.forwarded else {
            Issue.record("expected bytes, got \(String(describing: body.forwarded))")
            return
        }
        #expect(data == Data("short".utf8))
        #expect(body.logged?.text == "short")
    }

    @Test func copiesALongStreamToAFile() throws {
        let content = Data((0..<200_000).map { UInt8($0 % 251) })
        let stream = InputStream(data: content)

        let body = FloconRequestBody.read(stream: stream, limit: 1_000, temporaryDirectory: FileManager.default.temporaryDirectory)

        guard case .file(let url) = body.forwarded else {
            Issue.record("expected a file, got \(String(describing: body.forwarded))")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try Data(contentsOf: url) == content)
        #expect(body.logged?.data.count == 1_000)
        #expect(body.logged?.totalSize == 200_000)
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

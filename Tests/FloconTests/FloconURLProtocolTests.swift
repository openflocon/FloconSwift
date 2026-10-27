import Foundation
import Testing
@testable import Flocon

@Suite struct FloconURLProtocolTests {
    private let body = Data(#"{"query":"query GetCountry { country(code: \"FR\") { name } }"}"#.utf8)

    @Test func forwardedRequestKeepsABodyReadFromAStream() {
        var request = URLRequest(url: URL(string: "https://api.example.com/graphql")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)

        let read = FloconRequestBody.read(from: request, limit: 1_000)
        let forwarded = FloconURLProtocol.forwardedRequest(request, body: read.forwarded)

        #expect(read.forwarded == .data(body))
        #expect(forwarded.httpBody == body)
        #expect(forwarded.httpBodyStream == nil)
    }

    @Test func forwardedRequestKeepsABodySetAsData() {
        var request = URLRequest(url: URL(string: "https://api.example.com/graphql")!)
        request.httpMethod = "POST"
        request.httpBody = body

        let read = FloconRequestBody.read(from: request, limit: 1_000)
        let forwarded = FloconURLProtocol.forwardedRequest(request, body: read.forwarded)

        #expect(forwarded.httpBody == body)
    }

    @Test func forwardedRequestStreamsALongBodyFromAFile() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)

        let read = FloconRequestBody.read(from: request, limit: 4)
        guard case .file(let url) = read.forwarded else {
            Issue.record("expected a temporary file")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let forwarded = FloconURLProtocol.forwardedRequest(request, body: read.forwarded)

        #expect(forwarded.httpBody == nil)
        #expect(forwarded.httpBodyStream != nil)
        #expect(try Data(contentsOf: url) == body)
    }

    @Test func forwardedRequestWithoutBody() {
        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        let read = FloconRequestBody.read(from: request, limit: 1_000)
        let forwarded = FloconURLProtocol.forwardedRequest(request, body: read.forwarded)

        #expect(forwarded.httpBody == nil)
    }
}

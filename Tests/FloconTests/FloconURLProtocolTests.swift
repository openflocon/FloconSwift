import Foundation
import Testing
@testable import Flocon

@Suite struct FloconURLProtocolTests {
    private let body = Data(#"{"query":"query GetCountry { country(code: \"FR\") { name } }"}"#.utf8)

    @Test func forwardedRequestKeepsABodyReadFromAStream() {
        var request = URLRequest(url: URL(string: "https://api.example.com/graphql")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)

        let read = FloconURLProtocol.readBody(of: request)
        let forwarded = FloconURLProtocol.forwardedRequest(request, body: read)

        #expect(read == body)
        #expect(forwarded.httpBody == body)
        #expect(forwarded.httpBodyStream == nil)
    }

    @Test func forwardedRequestKeepsABodySetAsData() {
        var request = URLRequest(url: URL(string: "https://api.example.com/graphql")!)
        request.httpMethod = "POST"
        request.httpBody = body

        let forwarded = FloconURLProtocol.forwardedRequest(request, body: FloconURLProtocol.readBody(of: request))

        #expect(forwarded.httpBody == body)
    }

    @Test func forwardedRequestWithoutBody() {
        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        let forwarded = FloconURLProtocol.forwardedRequest(request, body: FloconURLProtocol.readBody(of: request))

        #expect(forwarded.httpBody == nil)
    }
}

import Foundation
import Testing
@_spi(FloconExtension) @testable import Flocon

@Suite struct FloconNetworkExtensionTests {
    @Test func doesNothingBeforeInitialize() {
        #expect(!Flocon.isNetworkLoggingEnabled)
        // no client: must not crash
        Flocon.logNetworkRequest(
            callId: "id", networkType: "grpc", url: "localhost:50051", method: "helloworld.Greeter/SayHello",
            startTime: Date(), headers: [:], body: "{}", size: 2
        )
    }

    @Test func encodesAGrpcResponse() throws {
        let response = FloconNetworkCallResponseRemote(
            floconCallId: "id",
            durationMs: 12,
            floconNetworkType: "grpc",
            isMocked: false,
            response: FloconNetworkResponse(
                httpCode: nil, contentType: "grpc", body: #"{"message":"Hello"}"#, headers: ["te": "trailers"],
                size: 19, grpcStatus: "OK", error: nil, requestHeaders: nil, isImage: false
            )
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(response)) as? [String: Any])

        #expect(json["floconNetworkType"] as? String == "grpc")
        #expect(json["responseGrpcStatus"] as? String == "OK")
        #expect(json["responseContentType"] as? String == "grpc")
        #expect(json["responseHttpCode"] is NSNull)
        #expect(json["responseError"] is NSNull)
        #expect((json["responseHeaders"] as? [String: String])?["te"] == "trailers")
    }
}

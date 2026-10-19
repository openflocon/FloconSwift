import Foundation
import Testing
@testable import Flocon

@Suite struct FloconNetworkModelsTests {
    @Test func encodesARequestLikeTheOtherSDKs() throws {
        let call = FloconNetworkCallRequest(
            callId: "id",
            networkType: "grpc",
            request: FloconNetworkRequest(
                url: "localhost:50051",
                method: "helloworld.Greeter/SayHello",
                startTime: Date(timeIntervalSince1970: 1),
                headers: ["a": "b"],
                body: "{}",
                size: 2
            )
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(FloconNetworkCallRequestRemote(call))) as? [String: Any])

        #expect(json["floconCallId"] as? String == "id")
        #expect(json["floconNetworkType"] as? String == "grpc")
        #expect(json["url"] as? String == "localhost:50051")
        #expect(json["method"] as? String == "helloworld.Greeter/SayHello")
        #expect(json["startTime"] as? Int == 1000)
        #expect((json["requestHeaders"] as? [String: String])?["a"] == "b")
        #expect(json["requestBody"] as? String == "{}")
        #expect(json["requestSize"] as? Int == 2)
        #expect(json["isMocked"] as? Bool == false)
    }

    @Test func encodesAGrpcResponseLikeTheOtherSDKs() throws {
        let call = FloconNetworkCallResponse(
            callId: "id",
            networkType: "grpc",
            durationMs: 12,
            response: FloconNetworkResponse(
                grpcStatus: "OK", contentType: "grpc", body: #"{"message":"Hello"}"#, size: 19, headers: ["te": "trailers"]
            )
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(FloconNetworkCallResponseRemote(call))) as? [String: Any])

        #expect(json["floconCallId"] as? String == "id")
        #expect(json["floconNetworkType"] as? String == "grpc")
        #expect(json["durationMs"] as? Double == 12)
        #expect(json["responseGrpcStatus"] as? String == "OK")
        #expect(json["responseContentType"] as? String == "grpc")
        #expect(json["responseHttpCode"] is NSNull)
        #expect(json["responseError"] is NSNull)
        #expect((json["responseHeaders"] as? [String: String])?["te"] == "trailers")
    }
}

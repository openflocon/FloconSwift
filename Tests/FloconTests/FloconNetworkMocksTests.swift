import Foundation
import Testing
@testable import Flocon

private final class SilentSender: FloconMessageSender {
    func send(plugin: String, method: String, body: String) {}
}

/// Always returns the same value, to make the random choices predictable.
private struct FixedGenerator: RandomNumberGenerator {
    let value: UInt64
    mutating func next() -> UInt64 { value }
}

@Suite struct FloconNetworkMocksTests {
    private let mocksJSON = #"""
    [
      {
        "expectation": { "urlPattern": "https://api\\.example\\.com/users.*", "method": "GET" },
        "response": {
          "httpCode": 200, "body": "{\"users\":[]}", "mediaType": "application/json",
          "delay": 500, "headers": { "X-Mocked": "true" }, "errorException": null
        }
      },
      {
        "expectation": { "urlPattern": ".*/login", "method": "*" },
        "response": {
          "httpCode": null, "body": null, "mediaType": null, "delay": 0,
          "headers": null, "errorException": "java.net.UnknownHostException"
        }
      },
      {
        "expectation": { "urlPattern": ".*", "method": "*" },
        "response": { "httpCode": null, "errorException": null }
      }
    ]
    """#

    private let badNetworkJSON = #"""
    {
      "latency": { "latencyTriggerProbability": 1.0, "minLatencyMs": 200, "maxLatencyMs": 200 },
      "errorProbability": 1.0,
      "errors": [
        { "weight": 2.0, "errorException": null, "errorCode": 500,
          "errorBody": "{\"error\":\"server\"}", "errorContentType": "application/json" },
        { "weight": 1.0, "errorException": "java.net.SocketTimeoutException",
          "errorCode": null, "errorBody": null, "errorContentType": null }
      ]
    }
    """#

    private func makeStore() -> FloconNetworkStore {
        FloconNetworkStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("flocon-network-\(UUID().uuidString)")
        )
    }

    // MARK: Mocks

    @Test func readsTheMocksOfTheDesktop() {
        let mocks = FloconNetworkMockRemote.parse(mocksJSON)

        // the last one has neither a code nor an error
        #expect(mocks.count == 2)
        #expect(mocks[0].delayMs == 500)
        #expect(mocks[0].response == .body(
            httpCode: 200, body: #"{"users":[]}"#, mediaType: "application/json", headers: ["X-Mocked": "true"]
        ))
        #expect(mocks[1].response == .error(exception: "java.net.UnknownHostException"))
    }

    @Test func matchesTheWholeUrlAndTheMethod() {
        let expectation = FloconNetworkMock.Expectation(urlPattern: #"https://api\.example\.com/users.*"#, method: "GET")

        #expect(expectation.matches(url: "https://api.example.com/users?page=1", method: "GET"))
        #expect(expectation.matches(url: "https://api.example.com/users", method: "get"))
        #expect(!expectation.matches(url: "https://api.example.com/users", method: "POST"))
        #expect(!expectation.matches(url: "http://proxy/https://api.example.com/users", method: "GET"))

        let any = FloconNetworkMock.Expectation(urlPattern: ".*/login", method: "*")
        #expect(any.matches(url: "https://example.com/login", method: "DELETE"))
        #expect(!any.matches(url: "https://example.com/login/more", method: "GET"))
    }

    @Test func ignoresAnInvalidPattern() {
        let expectation = FloconNetworkMock.Expectation(urlPattern: "(", method: "*")
        #expect(!expectation.matches(url: "(", method: "GET"))
    }

    @Test func turnsTheExceptionsIntoUrlErrors() {
        #expect(FloconNetworkMockResponse.urlError(forException: "java.net.UnknownHostException").code == .cannotFindHost)
        #expect(FloconNetworkMockResponse.urlError(forException: "java.net.SocketTimeoutException").code == .timedOut)
        #expect(FloconNetworkMockResponse.urlError(forException: "java.net.ConnectException").code == .cannotConnectToHost)
        #expect(FloconNetworkMockResponse.urlError(forException: "javax.net.ssl.SSLHandshakeException").code == .secureConnectionFailed)
        #expect(FloconNetworkMockResponse.urlError(forException: "java.io.IOException").code == .networkConnectionLost)
        #expect(FloconNetworkMockResponse.urlError(forException: "java.io.IOException").localizedDescription == "java.io.IOException")
    }

    // MARK: Bad network

    @Test func readsTheBadNetworkConfigOfTheDesktop() throws {
        let config = try #require(FloconBadNetworkConfigRemote.parse(badNetworkJSON))

        #expect(config.latency == .init(triggerProbability: 1, minLatencyMs: 200, maxLatencyMs: 200))
        #expect(config.errorProbability == 1)
        #expect(config.errors == [
            .init(weight: 2, response: .body(httpCode: 500, body: #"{"error":"server"}"#, mediaType: "application/json", headers: [:])),
            .init(weight: 1, response: .error(exception: "java.net.SocketTimeoutException")),
        ])
    }

    @Test func anEmptyConfigDisablesTheSimulation() {
        #expect(FloconBadNetworkConfigRemote.parse("{}") == nil)
    }

    @Test func picksTheLatencyAndTheErrorByWeight() throws {
        let config = try #require(FloconBadNetworkConfigRemote.parse(badNetworkJSON))

        var low = FixedGenerator(value: 0)
        #expect(config.randomLatencyMs(using: &low) == 200)
        #expect(config.randomError(using: &low) == config.errors[0])

        // close to the total weight: the last error
        var high = FixedGenerator(value: .max)
        #expect(config.randomError(using: &high) == config.errors[1])
    }

    @Test func doesNotFailWithoutErrorProbability() {
        let config = FloconBadNetworkConfig(
            latency: .init(triggerProbability: 0, minLatencyMs: 100, maxLatencyMs: 200),
            errorProbability: 0,
            errors: [.init(weight: 1, response: .error(exception: "java.io.IOException"))]
        )
        var generator = SystemRandomNumberGenerator()
        #expect(config.randomLatencyMs(using: &generator) == 0)
        #expect(config.randomError(using: &generator) == nil)
    }

    // MARK: Plugin

    @Test func appliesAndSavesTheMessagesOfTheDesktop() throws {
        let store = makeStore()
        let plugin = FloconNetworkPlugin(sender: SilentSender(), store: store)
        #expect(plugin.mocks.isEmpty)
        #expect(plugin.badNetworkConfig == nil)

        plugin.onMessageReceived(FloconMessageFromServer(plugin: "network", method: "setupMocks", body: mocksJSON))
        plugin.onMessageReceived(FloconMessageFromServer(plugin: "network", method: "setupBadNetworkConfig", body: badNetworkJSON))

        #expect(plugin.mock(url: "https://example.com/login", method: "POST")?.response == .error(exception: "java.net.UnknownHostException"))
        #expect(plugin.mock(url: "https://example.com/other", method: "GET") == nil)
        #expect(plugin.badNetworkConfig != nil)

        // restored on the next launch
        let relaunched = FloconNetworkPlugin(sender: SilentSender(), store: store)
        #expect(relaunched.mocks == plugin.mocks)
        #expect(relaunched.badNetworkConfig == plugin.badNetworkConfig)

        relaunched.onMessageReceived(FloconMessageFromServer(plugin: "network", method: "setupMocks", body: "[]"))
        relaunched.onMessageReceived(FloconMessageFromServer(plugin: "network", method: "setupBadNetworkConfig", body: "{}"))
        let cleared = FloconNetworkPlugin(sender: SilentSender(), store: store)
        #expect(cleared.mocks.isEmpty)
        #expect(cleared.badNetworkConfig == nil)
    }
}

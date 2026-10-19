import Foundation

/// JSON format of a mock sent by the desktop app (`setupMocks`).
struct FloconNetworkMockRemote: Decodable {
    struct Expectation: Decodable {
        let urlPattern: String
        let method: String
    }

    struct Response: Decodable {
        let httpCode: Int?
        let body: String?
        let mediaType: String?
        let delay: Int64?
        let headers: [String: String]?
        let errorException: String?
    }

    let expectation: Expectation
    let response: Response

    /// The mock, or `nil` when it has neither an HTTP code nor an error.
    var mock: FloconNetworkMock? {
        let result: FloconNetworkMockResponse
        if let exception = response.errorException {
            result = .error(exception: exception)
        } else if let httpCode = response.httpCode {
            result = .body(
                httpCode: httpCode,
                body: response.body ?? "",
                mediaType: response.mediaType ?? "",
                headers: response.headers ?? [:]
            )
        } else {
            return nil
        }
        return FloconNetworkMock(
            expectation: .init(urlPattern: expectation.urlPattern, method: expectation.method),
            response: result,
            delayMs: response.delay ?? 0
        )
    }

    /// Reads the body of a `setupMocks` message: a JSON array of mocks.
    static func parse(_ json: String) -> [FloconNetworkMock] {
        do {
            return try JSONDecoder().decode([FloconNetworkMockRemote].self, from: Data(json.utf8)).compactMap(\.mock)
        } catch {
            FloconLogger.logError("Cannot read the network mocks", error)
            return []
        }
    }
}

/// JSON format of a bad network configuration sent by the desktop app (`setupBadNetworkConfig`).
struct FloconBadNetworkConfigRemote: Decodable {
    struct Latency: Decodable {
        let latencyTriggerProbability: Double
        let minLatencyMs: Int64
        let maxLatencyMs: Int64
    }

    struct BadError: Decodable {
        let weight: Double
        let errorCode: Int?
        let errorBody: String?
        let errorContentType: String?
        let errorException: String?
    }

    let latency: Latency
    let errorProbability: Double
    let errors: [BadError]

    var config: FloconBadNetworkConfig {
        FloconBadNetworkConfig(
            latency: .init(
                triggerProbability: latency.latencyTriggerProbability,
                minLatencyMs: latency.minLatencyMs,
                maxLatencyMs: latency.maxLatencyMs
            ),
            errorProbability: errorProbability,
            errors: errors.map { error in
                let response: FloconNetworkMockResponse
                if let exception = error.errorException, !exception.isEmpty {
                    response = .error(exception: exception)
                } else {
                    response = .body(
                        httpCode: error.errorCode ?? 0,
                        body: error.errorBody ?? "",
                        mediaType: error.errorContentType ?? "",
                        headers: [:]
                    )
                }
                return FloconBadNetworkConfig.Error(weight: error.weight, response: response)
            }
        )
    }

    /// Reads the body of a `setupBadNetworkConfig` message.
    ///
    /// - Returns: The configuration, or `nil` to disable the simulation (the desktop sends `{}`).
    static func parse(_ json: String) -> FloconBadNetworkConfig? {
        try? JSONDecoder().decode(FloconBadNetworkConfigRemote.self, from: Data(json.utf8)).config
    }
}

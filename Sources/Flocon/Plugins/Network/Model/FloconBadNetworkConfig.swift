import Foundation

/// A bad network simulated by the Flocon desktop app: latency and random errors added to the calls.
public struct FloconBadNetworkConfig: Sendable, Equatable {
    /// Latency added to the calls.
    public struct Latency: Sendable, Equatable {
        /// Probability, between 0 and 1, that a call is delayed.
        public let triggerProbability: Double
        /// Minimum added latency, in milliseconds.
        public let minLatencyMs: Int64
        /// Maximum added latency, in milliseconds.
        public let maxLatencyMs: Int64

        /// Creates a latency setting.
        ///
        /// - Parameters:
        ///   - triggerProbability: Probability, between 0 and 1, that a call is delayed.
        ///   - minLatencyMs: Minimum added latency, in milliseconds.
        ///   - maxLatencyMs: Maximum added latency, in milliseconds.
        public init(triggerProbability: Double, minLatencyMs: Int64, maxLatencyMs: Int64) {
            self.triggerProbability = triggerProbability
            self.minLatencyMs = minLatencyMs
            self.maxLatencyMs = maxLatencyMs
        }
    }

    /// An error returned instead of the response of the server.
    public struct Error: Sendable, Equatable {
        /// Weight of this error against the other ones: the higher, the more often it is picked.
        public let weight: Double
        /// The response returned to the app.
        public let response: FloconNetworkMockResponse

        /// Creates an error.
        ///
        /// - Parameters:
        ///   - weight: Weight of this error against the other ones.
        ///   - response: The response returned to the app.
        public init(weight: Double, response: FloconNetworkMockResponse) {
            self.weight = weight
            self.response = response
        }
    }

    /// Latency added to the calls.
    public let latency: Latency
    /// Probability, between 0 and 1, that a call fails with one of ``errors``.
    public let errorProbability: Double
    /// The possible errors, one is picked according to its ``Error/weight``.
    public let errors: [Error]

    /// Creates a bad network configuration.
    ///
    /// - Parameters:
    ///   - latency: Latency added to the calls.
    ///   - errorProbability: Probability, between 0 and 1, that a call fails.
    ///   - errors: The possible errors.
    public init(latency: Latency, errorProbability: Double, errors: [Error]) {
        self.latency = latency
        self.errorProbability = errorProbability
        self.errors = errors
    }

    /// Picks the latency to add to a call.
    ///
    /// - Parameter generator: Source of randomness.
    /// - Returns: The latency in milliseconds, or `0` when the call is not delayed.
    func randomLatencyMs<G: RandomNumberGenerator>(using generator: inout G) -> Int64 {
        guard latency.triggerProbability > 0,
              latency.triggerProbability >= 1 || Double.random(in: 0..<1, using: &generator) < latency.triggerProbability
        else { return 0 }
        let low = max(0, latency.minLatencyMs)
        return Int64.random(in: low...max(low, latency.maxLatencyMs), using: &generator)
    }

    /// Picks the error a call fails with, if it fails.
    ///
    /// - Parameter generator: Source of randomness.
    /// - Returns: The error, or `nil` when the call does not fail.
    func randomError<G: RandomNumberGenerator>(using generator: inout G) -> Error? {
        guard errorProbability > 0, !errors.isEmpty,
              Double.random(in: 0..<1, using: &generator) < errorProbability
        else { return nil }
        let totalWeight = errors.reduce(0) { $0 + max(0, $1.weight) }
        guard totalWeight > 0 else { return errors[0] }
        var remaining = Double.random(in: 0..<totalWeight, using: &generator)
        for error in errors {
            remaining -= max(0, error.weight)
            if remaining < 0 { return error }
        }
        return errors[errors.count - 1]
    }
}

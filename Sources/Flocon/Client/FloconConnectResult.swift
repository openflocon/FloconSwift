import Foundation

/// Result of ``Flocon/connect(address:)``.
///
/// Whatever the result, the messages kept so far are not lost: call ``Flocon/connect(address:)`` again to retry.
public enum FloconConnectResult: Sendable, Equatable {
    /// Connected: what was kept has been sent, the next messages are sent right away.
    case connected
    /// The SDK is not started, see ``startFlocon(_:)``.
    case notStarted
    /// The address could not be read, with the reason.
    case invalidAddress(String)
    /// The connection attempt failed, with the error message.
    case failed(String)
}

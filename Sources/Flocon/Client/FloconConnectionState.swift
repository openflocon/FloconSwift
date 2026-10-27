import Foundation

/// State of the connection to the Flocon desktop app.
///
/// Read it with ``Flocon/connectionState``, or follow it with ``Flocon/connectionStates``.
public enum FloconConnectionState: Sendable, Equatable {
    /// The SDK is not started.
    case idle
    /// Not connected: the messages are kept in memory until the connection is up.
    ///
    /// This is the state after ``startFlocon(_:)`` with ``FloconBuilder/connectLater(bufferCapacity:)``
    /// until ``Flocon/connect(to:)`` is called, and right after a connection is lost.
    case buffering
    /// Opening the connection to the desktop app.
    case connecting
    /// Connected: the messages are sent right away.
    case connected
    /// The last attempt to connect failed, with the reason. The messages are still kept.
    case failed(String)
}

/// Holds the current ``FloconConnectionState`` and feeds the streams that follow it.
final class FloconConnectionStateStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _state = FloconConnectionState.idle
    private var continuations: [UUID: AsyncStream<FloconConnectionState>.Continuation] = [:]

    var state: FloconConnectionState {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    /// Updates the state and tells the streams. Setting the current state again does nothing.
    func set(_ newState: FloconConnectionState) {
        lock.lock(); defer { lock.unlock() }
        guard newState != _state else { return }
        _state = newState
        // inside the lock, so that every stream sees the changes in the same order
        continuations.values.forEach { $0.yield(newState) }
    }

    /// A stream that starts with the current state, then emits each change.
    var stream: AsyncStream<FloconConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            continuation.yield(_state)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.lock(); defer { lock.unlock() }
                continuations[id] = nil
            }
        }
    }
}

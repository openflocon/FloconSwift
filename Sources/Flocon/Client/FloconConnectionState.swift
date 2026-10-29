import Foundation

/// State of the connection to the Flocon desktop app.
///
/// Read it with ``Flocon/connectionState``, or follow it with ``Flocon/connectionStates``.
public enum FloconConnectionState: Sendable, Equatable {
    /// The SDK is not started.
    case idle
    /// Not connected: the messages are kept in memory until the connection is up.
    ///
    /// This is the state while no desktop app is reachable, and right after a connection is lost.
    case buffering
    /// Opening the connection to the desktop app.
    case connecting
    /// Connected: the messages are sent right away.
    case connected
    /// The last attempt to connect failed, with the reason. The messages are still kept.
    case failed(String)
}

/// Holds the state of each connection (one per address), and the ``FloconConnectionState`` published
/// to the app: connected as soon as one address is, else the most advanced state of the addresses.
final class FloconConnectionStateStore: @unchecked Sendable {
    private let lock = NSLock()
    private var linkStates: [UUID: FloconConnectionState] = [:]
    private var _state = FloconConnectionState.idle
    private var continuations: [UUID: AsyncStream<FloconConnectionState>.Continuation] = [:]

    var state: FloconConnectionState {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    /// Updates the state of one connection.
    func set(_ newState: FloconConnectionState, for link: UUID) {
        lock.lock(); defer { lock.unlock() }
        linkStates[link] = newState
        publish()
    }

    /// Forgets a connection that was closed on purpose.
    func clear(_ link: UUID) {
        lock.lock(); defer { lock.unlock() }
        linkStates[link] = nil
        publish()
    }

    /// Tells the streams if the state changed. Setting the current state again does nothing.
    private func publish() {
        let states = Array(linkStates.values)
        let newState = states.first { $0 == .connected }
            ?? states.first { $0 == .connecting }
            ?? states.first { if case .failed = $0 { true } else { false } }
            ?? states.first
            ?? .idle
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

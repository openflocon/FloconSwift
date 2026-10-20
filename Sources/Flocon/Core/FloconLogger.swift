import Foundation

/// Console logger of the SDK. Every line is prefixed with `[Flocon]`.
///
/// Off by default: printing every message, network bodies included, is slow.
/// Turn it on with ``Flocon/isLoggingEnabled``.
enum FloconLogger {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _isEnabled = false

    /// Longest payload printed by ``log(payload:_:)``, in characters.
    static let maxPayloadLength = 500

    static var isEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isEnabled }
        set { lock.lock(); defer { lock.unlock() }; _isEnabled = newValue }
    }

    /// The message is only built when logging is on.
    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[Flocon] \(message())")
    }

    /// Logs a prefix and a payload, truncated to ``maxPayloadLength`` characters.
    static func log(payload: @autoclosure () -> String, _ prefix: String) {
        guard isEnabled else { return }
        print("[Flocon] \(prefix) \(truncated(payload()))")
    }

    static func logError(_ message: @autoclosure () -> String, _ error: Error? = nil) {
        guard isEnabled else { return }
        if let error {
            print("[Flocon] \(message()) — \(error)")
        } else {
            print("[Flocon] \(message())")
        }
    }

    static func truncated(_ text: String) -> String {
        // utf8.count is O(1), count is not
        guard text.utf8.count > maxPayloadLength else { return text }
        return "\(text.prefix(maxPayloadLength))… (\(text.utf8.count) bytes)"
    }
}

extension Flocon {
    /// Whether the SDK prints its logs in the console, prefixed with `[Flocon]`. Off by default.
    ///
    /// Long payloads, such as network bodies, are truncated.
    public static var isLoggingEnabled: Bool {
        get { FloconLogger.isEnabled }
        set { FloconLogger.isEnabled = newValue }
    }
}

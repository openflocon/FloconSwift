import Foundation

enum FloconLogger {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _isEnabled = true

    static var isEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isEnabled }
        set { lock.lock(); defer { lock.unlock() }; _isEnabled = newValue }
    }

    static func log(_ message: String) {
        guard isEnabled else { return }
        print("[Flocon] \(message)")
    }

    static func logError(_ message: String, _ error: Error? = nil) {
        guard isEnabled else { return }
        if let error {
            print("[Flocon] \(message) — \(error)")
        } else {
            print("[Flocon] \(message)")
        }
    }
}

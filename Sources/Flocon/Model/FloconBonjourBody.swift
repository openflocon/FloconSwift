import Foundation

/// Body of the `bonjour` message, the first one sent to the desktop app on a new connection.
struct FloconBonjourBody: Encodable, Equatable {
    /// How the app reached the desktop app.
    enum ConnectionType: String, Encodable {
        /// The default address, `localhost` (simulator, or a device through a tunnel).
        case `default`
        /// The address given to ``Flocon/connect(address:)``.
        case wifi
    }

    let connectionType: ConnectionType

    /// The SDK family, so the desktop app compares this app with the latest release of the right SDK.
    let sdk = "swift"

    /// The JSON sent as the body of the message.
    func json() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

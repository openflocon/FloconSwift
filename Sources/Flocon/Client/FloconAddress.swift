import Foundation

/// The address given to ``Flocon/connect(address:)`` cannot be read.
struct FloconAddressError: Error, Equatable {
    let message: String
}

/// The WebSocket URL of the desktop app at `address`: only its IP address or host, such as
/// `192.168.1.20` or `my-mac.local`. The port is the one of ``FloconConfig/webSocketPort``, `9023`.
///
/// - Throws: ``FloconAddressError`` if the address is empty, or has a scheme, a port or a path.
func floconWebSocketURL(address: String, port: Int) throws -> URL {
    let host = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let isReadable = !host.isEmpty && !host.contains { $0 == ":" || $0 == "/" || $0 == "?" || $0 == "#" || $0.isWhitespace }
    guard isReadable, let url = URL(string: "ws://\(host):\(port)") else {
        throw FloconAddressError(
            message: "Cannot read '\(address)', enter only the IP address of the computer, such as 192.168.1.20 "
                + "(no port: it is always \(port))"
        )
    }
    return url
}

/// Where the last desktop address the SDK connected to is kept between two launches of the app.
protocol FloconAddressStore: Sendable {
    /// The address saved by ``save(_:)``, or `nil`.
    func load() -> String?
    func save(_ address: String)
}

/// Keeps the address in the `UserDefaults` of the app.
struct FloconUserDefaultsAddressStore: FloconAddressStore {
    private static let key = "io.github.openflocon.flocon.lastAddress"

    func load() -> String? {
        UserDefaults.standard.string(forKey: Self.key)
    }

    func save(_ address: String) {
        UserDefaults.standard.set(address, forKey: Self.key)
    }
}

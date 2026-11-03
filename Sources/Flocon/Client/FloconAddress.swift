import Foundation

/// The address given to ``Flocon/connect(address:)`` cannot be read.
struct FloconAddressError: Error, Equatable {
    let message: String
}

/// The WebSocket URL of the desktop app at `address`: its IP address or host, with an optional port,
/// such as `192.168.1.20`, `my-mac.local` or `192.168.1.20:9100`.
///
/// When the address has no port, `port` is used (``FloconConfig/webSocketPort``). Only IPv4 addresses and
/// host names are read: no scheme, path, query, fragment, whitespace nor IPv6.
///
/// - Parameters:
///   - address: The address to read.
///   - port: The port used when `address` does not contain one.
/// - Throws: ``FloconAddressError`` if the address is empty, has a scheme, a path, or a port that is not
///   an integer from 1 to 65535 with at most 5 digits.
func floconWebSocketURL(address: String, port: Int) throws -> URL {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalid = FloconAddressError(
        message: "Cannot read '\(address)', enter the IP address of the computer, such as 192.168.1.20, "
            + "with an optional port, such as 192.168.1.20:9100 (without scheme nor path)"
    )
    let hasForbiddenCharacter = trimmed.contains { $0 == "/" || $0 == "?" || $0 == "#" || $0.isWhitespace }
    let parts = trimmed.split(separator: ":", maxSplits: .max, omittingEmptySubsequences: false)
    guard !trimmed.isEmpty, !hasForbiddenCharacter, parts.count <= 2, let host = parts.first, !host.isEmpty else {
        throw invalid
    }
    var resolvedPort = port
    if parts.count == 2 {
        let text = parts[1]
        guard !text.isEmpty, text.count <= 5, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(text), (1...65535).contains(value) else {
            throw FloconAddressError(
                message: "Cannot read the port of '\(address)', it must be an integer from 1 to 65535, with at most 5 digits"
            )
        }
        resolvedPort = value
    }
    guard let url = URL(string: "wss://\(host):\(resolvedPort)") else { throw invalid }
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

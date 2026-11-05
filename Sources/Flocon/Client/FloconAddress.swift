import Foundation

/// The address given to ``Flocon/connect(address:)`` cannot be read.
struct FloconAddressError: Error, Equatable {
    let message: String
}

/// A desktop app to connect to: its host and the two ports of its servers.
struct FloconAddress: Equatable, Sendable {
    let host: String
    let webSocketPort: Int
    let httpPort: Int

    /// The WebSocket URL of the desktop app.
    var webSocketURL: URL {
        URL(string: "wss://\(host):\(webSocketPort)") ?? URL(string: "wss://localhost:\(webSocketPort)")!
    }

    /// Reads `address`: an IP address or a host, with optional ports, such as `192.168.1.20`,
    /// `my-mac.local`, `192.168.1.20:10023` (WebSocket port) or `192.168.1.20:10023:10024`
    /// (WebSocket port, then HTTP port).
    ///
    /// An omitted port takes the given default (``FloconConfig/webSocketPort``, ``FloconConfig/httpPort``).
    /// Only IPv4 addresses and host names are read: no scheme, path, query, fragment, whitespace nor IPv6.
    ///
    /// - Parameters:
    ///   - address: The address to read.
    ///   - webSocketPort: The WebSocket port used when `address` does not contain one.
    ///   - httpPort: The HTTP port used when `address` does not contain one.
    /// - Throws: ``FloconAddressError`` if the address is empty, has a scheme, a path, more than two ports, or a
    ///   port that is not an integer from 1 to 65535 with at most 5 digits.
    init(parsing address: String, webSocketPort: Int, httpPort: Int) throws {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = FloconAddressError(
            message: "Cannot read '\(address)', enter the IP address of the computer, such as 192.168.1.20, "
                + "with optional ports, such as 192.168.1.20:10023:10024 (WebSocket port, then HTTP port), "
                + "without scheme nor path"
        )
        let hasForbiddenCharacter = trimmed.contains { $0 == "/" || $0 == "?" || $0 == "#" || $0.isWhitespace }
        let parts = trimmed.split(separator: ":", maxSplits: .max, omittingEmptySubsequences: false)
        guard !trimmed.isEmpty, !hasForbiddenCharacter, parts.count <= 3, let host = parts.first, !host.isEmpty else {
            throw invalid
        }
        func port(_ text: Substring) throws -> Int {
            guard !text.isEmpty, text.count <= 5, text.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(text), (1...65535).contains(value) else {
                throw FloconAddressError(
                    message: "Cannot read the ports of '\(address)', each must be an integer from 1 to 65535, with at most 5 digits"
                )
            }
            return value
        }
        self.host = String(host)
        self.webSocketPort = parts.count >= 2 ? try port(parts[1]) : webSocketPort
        self.httpPort = parts.count == 3 ? try port(parts[2]) : httpPort
        guard URL(string: "wss://\(self.host):\(self.webSocketPort)") != nil else { throw invalid }
    }

    /// The address kept for the next launch: the host alone when both ports are the given ones, otherwise
    /// `host:webSocketPort:httpPort`.
    func stored(webSocketPort defaultWebSocketPort: Int, httpPort defaultHttpPort: Int) -> String {
        if webSocketPort == defaultWebSocketPort && httpPort == defaultHttpPort { return host }
        return "\(host):\(webSocketPort):\(httpPort)"
    }

    init(host: String, webSocketPort: Int, httpPort: Int) {
        self.host = host
        self.webSocketPort = webSocketPort
        self.httpPort = httpPort
    }
}

/// Where the last desktop address the SDK connected to is kept between two launches of the app.
protocol FloconAddressStore: Sendable {
    /// The address saved by ``save(_:)``, or `nil`.
    func load() -> String?
    func save(_ address: String)

    /// Forgets the address saved by ``save(_:)``.
    func clear()
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

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}

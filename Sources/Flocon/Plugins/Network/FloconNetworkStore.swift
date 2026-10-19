import Foundation

/// Keeps the mocks and the bad network configuration on disk, so they apply from the launch
/// of the app, before it connects to the desktop.
///
/// The bodies of the desktop messages are saved as they are.
struct FloconNetworkStore: Sendable {
    let directory: URL

    /// Store of the running app, in `Library/Application Support/flocon_network`.
    static let app = FloconNetworkStore(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("flocon_network", isDirectory: true)
    )

    private var mocksURL: URL { directory.appendingPathComponent("flocon_network_mocks.json") }
    private var badNetworkConfigURL: URL { directory.appendingPathComponent("flocon_network_bad_config.json") }

    var mocksJSON: String? {
        get { read(mocksURL) }
        nonmutating set { write(newValue, to: mocksURL) }
    }

    var badNetworkConfigJSON: String? {
        get { read(badNetworkConfigURL) }
        nonmutating set { write(newValue, to: badNetworkConfigURL) }
    }

    private func read(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    private func write(_ json: String?, to url: URL) {
        guard let json else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(json.utf8).write(to: url, options: .atomic)
        } catch {
            FloconLogger.logError("Cannot save the network configuration", error)
        }
    }
}

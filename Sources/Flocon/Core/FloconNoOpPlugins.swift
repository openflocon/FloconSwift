import Foundation

/// A sender that drops every message, for the plugins returned while Flocon is not started.
final class FloconNoOpSender: FloconMessageSender, FloconFileSender, @unchecked Sendable {
    func send(plugin: String, method: String, body: String) {}

    func send<T: Encodable & Sendable>(plugin: String, method: String, value: T) {}

    func sendFile(at fileURL: URL, remotePath: String, requestId: String) async {}
}

/// The plugins returned by `Flocon.<name>Plugin` when Flocon is not initialized, or when the
/// plugin is not installed: they accept every call and send nothing.
enum FloconNoOpPlugins {
    static let sender = FloconNoOpSender()

    // an empty folder of its own, so that the saved mocks of the app are not loaded
    static let network = FloconNetworkPlugin(
        sender: sender,
        store: FloconNetworkStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("flocon_no_op", isDirectory: true)
        )
    )
    static let analytics = FloconAnalyticsPlugin(sender: sender)
    static let featureFlags = FloconFeatureFlagsPlugin(sender: sender)
    static let table = FloconTablePlugin(sender: sender)
    static let preferences = FloconPreferencesPlugin(sender: sender)
    static let database = FloconDatabasePlugin(sender: sender)
    static let files = FloconFilesPlugin(sender: sender, fileSender: sender)
    static let dashboard = FloconDashboardPlugin(sender: sender)
    static let deeplinks = FloconDeeplinksPlugin(sender: sender)
}

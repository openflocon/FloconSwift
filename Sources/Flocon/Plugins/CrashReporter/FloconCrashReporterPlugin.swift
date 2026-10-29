import Foundation

/// Reports the crashes of the app to the Flocon desktop app.
///
/// A crash cannot be sent while the app crashes: it is saved on disk, and sent on the next
/// connection, after which it is deleted. See ``FloconConfig/isCrashReporterEnabled``.
final class FloconCrashReporterPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "crash_reporter"
    private static let methodReportCrash = "report_crash"

    let pluginName = FloconCrashReporterPlugin.name
    private weak var sender: FloconMessageSender?
    private let store: FloconCrashStore
    private let queue = DispatchQueue(label: "io.github.openflocon.crashreporter")

    init(sender: FloconMessageSender, store: FloconCrashStore = .app) {
        self.sender = sender
        self.store = store
    }

    /// Installs the crash handlers. A crash of the previous launch, if any, is kept to be sent.
    func installCrashHandlers() {
        FloconSignalCrashHandler.install(store: store)
        FloconExceptionCrashHandler.install(store: store)
    }

    func onConnectedToServer() {
        queue.async { self.sendPendingCrashes() }
    }

    /// The desktop app sends nothing to this plugin.
    func onMessageReceived(_ message: FloconMessageFromServer) {}

    private func sendPendingCrashes() {
        let reports = store.pendingReports()
        guard !reports.isEmpty, let sender else { return }
        do {
            let data = try JSONEncoder().encode(reports)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender.send(plugin: pluginName, method: Self.methodReportCrash, body: json)
            // queued in order by the client, and kept while disconnected
            reports.forEach(store.delete)
            FloconLogger.log("Sent \(reports.count) crash report(s)")
        } catch {
            FloconLogger.logError("Crash report json mapping error", error)
        }
    }
}

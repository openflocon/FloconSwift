import Foundation

/// Answers the device requests of the Flocon desktop app, whatever the installed plugins.
///
/// When the desktop asks for the app icon (`get_app_icon`), replies with a base64 PNG (`app_icon`).
final class FloconDeviceHandler: @unchecked Sendable {
    static let pluginName = "device"
    private static let methodGetAppIcon = "get_app_icon"  // desktop -> app
    private static let methodAppIcon = "app_icon"        // app -> desktop

    private weak var sender: FloconMessageSender?
    private let icon: @Sendable () async -> String?

    /// - Parameters:
    ///   - sender: Where the answers are sent.
    ///   - icon: Reads the app icon as a base64 PNG, `nil` if there is none.
    init(sender: FloconMessageSender, icon: @escaping @Sendable () async -> String? = { await FloconAppIcon.base64PNG() }) {
        self.sender = sender
        self.icon = icon
    }

    /// Handles a message of the desktop.
    ///
    /// - Returns: `true` if the message was a device request, `false` if it is for a plugin.
    func handle(_ message: FloconMessageFromServer) -> Bool {
        guard message.plugin == Self.pluginName, message.method == Self.methodGetAppIcon else { return false }
        // off the main thread on iOS, see FloconAppIcon
        Task { await sendAppIcon() }
        return true
    }

    func sendAppIcon() async {
        guard let icon = await icon() else {
            FloconLogger.log("App icon not found")
            return
        }
        sender?.send(plugin: Self.pluginName, method: Self.methodAppIcon, body: icon)
    }
}

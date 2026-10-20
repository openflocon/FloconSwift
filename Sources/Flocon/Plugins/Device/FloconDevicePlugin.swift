import Foundation

/// Answers the device requests of the Flocon desktop app.
///
/// When the desktop asks for the app icon (`getAppIcon`), replies with a base64 PNG (`appIcon`).
/// Restarting the app (`restartApp`) is not possible on iOS and is ignored.
final class FloconDevicePlugin: FloconPlugin, @unchecked Sendable {
    static let name = "device"
    private static let methodGetAppIcon = "getAppIcon"  // desktop -> app
    private static let methodAppIcon = "appIcon"        // app -> desktop

    let pluginName = FloconDevicePlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    func onConnectedToServer() {}

    func onMessageReceived(_ message: FloconMessageFromServer) {
        switch message.method {
        case Self.methodGetAppIcon:
            // off the main thread on iOS, see FloconAppIcon
            Task { [weak self] in
                guard let self, let icon = await FloconAppIcon.base64PNG() else {
                    FloconLogger.log("App icon not found")
                    return
                }
                self.sender?.send(plugin: self.pluginName, method: Self.methodAppIcon, body: icon)
            }
        default:
            break
        }
    }
}

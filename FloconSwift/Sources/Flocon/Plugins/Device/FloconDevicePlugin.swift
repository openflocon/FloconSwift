import Foundation

/// Équivalent de FloconDevicePluginImpl (flocon/.../plugins/device).
/// Le desktop demande l'icône (`getAppIcon`), on répond `appIcon` avec un PNG en base64.
/// `restartApp` n'est pas possible sur iOS : ignoré.
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
            // UIImage / NSWorkspace : on passe par le main actor
            Task { @MainActor [weak self] in
                guard let self, let icon = FloconAppIcon.base64PNG() else {
                    FloconLogger.log("Icône de l'app introuvable")
                    return
                }
                self.sender?.send(plugin: self.pluginName, method: Self.methodAppIcon, body: icon)
            }
        default:
            break
        }
    }
}

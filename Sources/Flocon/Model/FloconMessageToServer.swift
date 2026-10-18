import Foundation

/// Envelope of every message sent to the desktop app: the payload of a plugin,
/// plus the identity of the app and device that sent it.
struct FloconMessageToServer: Encodable {
    let deviceId: String
    let plugin: String
    let body: String
    let appName: String
    let appPackageName: String
    let method: String
    let deviceName: String
    let appInstance: Int64
    let platform: String
    let versionName: String
}

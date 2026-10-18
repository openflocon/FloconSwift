import Foundation

// Équivalent de FloconMessageToServer côté Android.
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

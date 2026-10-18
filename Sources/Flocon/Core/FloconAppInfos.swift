import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Identity of the app and device, sent with every message.
struct FloconAppInfos: Sendable {
    let deviceId: String
    let deviceName: String
    let platform: String
    let appName: String
    let appPackageName: String

    /// Reads the current app and device information.
    ///
    /// `UIDevice` is main-actor isolated. The SDK awaits this from its outbox task, so that
    /// ``Flocon/initialize(config:)`` can still be called from any thread.
    @MainActor
    static func current() -> FloconAppInfos {
        let bundle = Bundle.main
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "unknown"
        let bundleId = bundle.bundleIdentifier ?? "unknown"

        #if canImport(UIKit)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name
        let platform = "ios"
        #else
        let deviceId = Host.current().localizedName ?? UUID().uuidString
        let deviceName = Host.current().localizedName ?? "mac"
        let platform = "macos"
        #endif

        return FloconAppInfos(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: platform,
            appName: appName,
            appPackageName: bundleId
        )
    }
}

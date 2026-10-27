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
    /// Runs off the main actor: only the `UIDevice` properties, which are main-actor isolated,
    /// are read there. On macOS, `Host.current()` can take a while to resolve the host name, so
    /// it stays off the main thread. ``FloconClient`` reads this once per launch.
    @concurrent
    static func current() async -> FloconAppInfos {
        let bundle = Bundle.main
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "unknown"
        let bundleId = bundle.bundleIdentifier ?? "unknown"

        #if canImport(UIKit)
        let (vendorId, deviceName) = await MainActor.run {
            (UIDevice.current.identifierForVendor?.uuidString, UIDevice.current.name)
        }
        let deviceId = vendorId ?? UUID().uuidString
        let platform = "ios"
        #else
        let hostName = Host.current().localizedName
        let deviceId = hostName ?? UUID().uuidString
        let deviceName = hostName ?? "mac"
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

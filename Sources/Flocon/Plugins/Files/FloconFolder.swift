import Foundation

/// A folder shown at the top of the Files section of the Flocon desktop app.
///
/// The app shows `Documents`, `Application Support`, `Caches`, `tmp` and the whole app container
/// without anything to register. Register the other folders, such as an App Group container,
/// with ``Flocon.filesPlugin.register(displayName:url:)`` or ``floconRegisterAppGroup(_:)``.
public struct FloconFolder: Sendable, Equatable {
    /// Name shown in the desktop app.
    public let displayName: String
    /// Location of the folder.
    public let url: URL

    /// Creates a folder.
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - url: Location of the folder.
    public init(displayName: String, url: URL) {
        self.displayName = displayName
        self.url = url
    }
}

extension FloconFilesPlugin {
    /// Shows a folder in the Files section of the Flocon desktop app.
    ///
    /// ```swift
    /// let url = URL.documentsDirectory.appending(path: "exports")
    /// Flocon.filesPlugin.register(displayName: "Exports", url: url)
    /// ```
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - url: Location of the folder.
    public func register(displayName: String, url: URL) {
        register(FloconFolder(displayName: displayName, url: url))
    }

    /// Shows a folder in the Files section of the Flocon desktop app.
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - absolutePath: Path of the folder.
    public func register(displayName: String, absolutePath: String) {
        register(displayName: displayName, url: URL(fileURLWithPath: absolutePath, isDirectory: true))
    }

    /// Shows the container of an App Group, shared with the widgets and extensions of the app,
    /// in the Files section of the Flocon desktop app.
    ///
    /// ```swift
    /// Flocon.filesPlugin.registerAppGroup("group.com.example.app")
    /// ```
    ///
    /// The app must have the App Groups capability with this identifier; otherwise nothing is shown.
    ///
    /// - Parameter identifier: The App Group identifier.
    public func registerAppGroup(_ identifier: String) {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            FloconLogger.log("No container for the App Group \(identifier): check the App Groups capability")
            return
        }
        register(displayName: "App Group · \(identifier)", url: url)
    }
}

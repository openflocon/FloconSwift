import Foundation

/// A folder shown at the top of the Files section of the Flocon desktop app.
///
/// The app shows `Documents`, `Application Support`, `Caches`, `tmp` and the whole app container
/// without anything to register. Register the other folders, such as an App Group container,
/// with ``floconRegisterFolder(displayName:url:)`` or ``floconRegisterAppGroup(_:)``.
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

/// Shows a folder in the Files section of the Flocon desktop app, where its content can be
/// browsed, downloaded and deleted.
///
/// Registering the same folder again replaces its name. A folder that does not exist is not shown.
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameter folder: The folder.
public func floconRegisterFolder(_ folder: FloconFolder) {
    Flocon.shared.filesPlugin?.register(folder)
}

/// Shows a folder in the Files section of the Flocon desktop app.
///
/// ```swift
/// let url = URL.documentsDirectory.appending(path: "exports")
/// floconRegisterFolder(displayName: "Exports", url: url)
/// ```
///
/// - Parameters:
///   - displayName: Name shown in the desktop app.
///   - url: Location of the folder.
public func floconRegisterFolder(displayName: String, url: URL) {
    floconRegisterFolder(FloconFolder(displayName: displayName, url: url))
}

/// Shows a folder in the Files section of the Flocon desktop app.
///
/// - Parameters:
///   - displayName: Name shown in the desktop app.
///   - absolutePath: Path of the folder.
public func floconRegisterFolder(displayName: String, absolutePath: String) {
    floconRegisterFolder(displayName: displayName, url: URL(fileURLWithPath: absolutePath, isDirectory: true))
}

/// Shows the container of an App Group, shared with the widgets and extensions of the app,
/// in the Files section of the Flocon desktop app.
///
/// ```swift
/// floconRegisterAppGroup("group.com.example.app")
/// ```
///
/// The app must have the App Groups capability with this identifier; otherwise nothing is shown.
///
/// - Parameter identifier: The App Group identifier.
public func floconRegisterAppGroup(_ identifier: String) {
    guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
        FloconLogger.log("No container for the App Group \(identifier): check the App Groups capability")
        return
    }
    floconRegisterFolder(displayName: "App Group · \(identifier)", url: url)
}

extension Flocon {
    /// Shows a folder in the desktop app. See ``floconRegisterFolder(_:)``.
    ///
    /// - Parameter folder: The folder.
    public static func registerFolder(_ folder: FloconFolder) {
        floconRegisterFolder(folder)
    }

    /// Shows the container of an App Group in the desktop app. See ``floconRegisterAppGroup(_:)``.
    ///
    /// - Parameter identifier: The App Group identifier.
    public static func registerAppGroup(_ identifier: String) {
        floconRegisterAppGroup(identifier)
    }
}

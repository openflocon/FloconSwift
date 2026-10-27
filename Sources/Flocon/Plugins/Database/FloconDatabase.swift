import Foundation

/// A SQLite database shown in the Database section of the Flocon desktop app.
///
/// The SQLite files of `Documents` and `Library/Application Support` are shown without being
/// registered. Register the other ones, or give a database a clearer name, with
/// ``Flocon.databasePlugin.register(displayName:url:)``.
public struct FloconDatabase: Sendable, Equatable {
    /// Name shown in the desktop app.
    public let displayName: String
    /// Location of the SQLite file.
    public let url: URL

    /// Creates a database.
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - url: Location of the SQLite file.
    public init(displayName: String, url: URL) {
        self.displayName = displayName
        self.url = url
    }
}

extension FloconDatabasePlugin {
    /// Shows a SQLite database in the Flocon desktop app, where it can be queried.
    ///
    /// ```swift
    /// let url = URL.documentsDirectory.appending(path: "app.sqlite")
    /// Flocon.databasePlugin.register(displayName: "App", url: url)
    /// ```
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - url: Location of the SQLite file.
    public func register(displayName: String, url: URL) {
        register(FloconDatabase(displayName: displayName, url: url))
    }

    /// Shows a SQLite database in the Flocon desktop app, where it can be queried.
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the desktop app.
    ///   - absolutePath: Path of the SQLite file.
    public func register(displayName: String, absolutePath: String) {
        register(displayName: displayName, url: URL(fileURLWithPath: absolutePath))
    }
}

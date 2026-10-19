import Foundation

/// A SQLite database shown in the Database section of the Flocon desktop app.
///
/// The SQLite files of `Documents` and `Library/Application Support` are shown without being
/// registered. Register the other ones, or give a database a clearer name, with
/// ``floconRegisterDatabase(displayName:url:)``.
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

/// Shows a SQLite database in the Flocon desktop app, where it can be queried.
///
/// Registering the same file again replaces its name. A file that does not exist is not shown.
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameter database: The database.
public func floconRegisterDatabase(_ database: FloconDatabase) {
    Flocon.shared.databasePlugin?.register(database)
}

/// Shows a SQLite database in the Flocon desktop app, where it can be queried.
///
/// ```swift
/// let url = URL.documentsDirectory.appending(path: "app.sqlite")
/// floconRegisterDatabase(displayName: "App", url: url)
/// ```
///
/// - Parameters:
///   - displayName: Name shown in the desktop app.
///   - url: Location of the SQLite file.
public func floconRegisterDatabase(displayName: String, url: URL) {
    floconRegisterDatabase(FloconDatabase(displayName: displayName, url: url))
}

/// Shows a SQLite database in the Flocon desktop app, where it can be queried.
///
/// - Parameters:
///   - displayName: Name shown in the desktop app.
///   - absolutePath: Path of the SQLite file.
public func floconRegisterDatabase(displayName: String, absolutePath: String) {
    floconRegisterDatabase(displayName: displayName, url: URL(fileURLWithPath: absolutePath))
}

/// Shows a query run by the app in the Flocon desktop app.
///
/// Call it from the trace hook of your database library, for example with GRDB:
///
/// ```swift
/// var configuration = Configuration()
/// configuration.prepareDatabase { db in
///     db.trace { event in
///         floconLogDatabaseQuery(dbName: "app", sqlQuery: "\(event)")
///     }
/// }
/// ```
///
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameters:
///   - dbName: Name of the database, as shown in the desktop app.
///   - sqlQuery: The SQL query.
///   - bindArgs: Values bound to the query; `nil` is shown as `null`.
public func floconLogDatabaseQuery(dbName: String, sqlQuery: String, bindArgs: [Any?] = []) {
    Flocon.shared.databasePlugin?.logQuery(dbName: dbName, sqlQuery: sqlQuery, bindArgs: bindArgs)
}

extension Flocon {
    /// Shows a SQLite database in the desktop app. See ``floconRegisterDatabase(_:)``.
    ///
    /// - Parameter database: The database.
    public static func registerDatabase(_ database: FloconDatabase) {
        floconRegisterDatabase(database)
    }

    /// Shows a query run by the app in the desktop app. See ``floconLogDatabaseQuery(dbName:sqlQuery:bindArgs:)``.
    ///
    /// - Parameters:
    ///   - dbName: Name of the database, as shown in the desktop app.
    ///   - sqlQuery: The SQL query.
    ///   - bindArgs: Values bound to the query.
    public static func logDatabaseQuery(dbName: String, sqlQuery: String, bindArgs: [Any?] = []) {
        floconLogDatabaseQuery(dbName: dbName, sqlQuery: sqlQuery, bindArgs: bindArgs)
    }
}

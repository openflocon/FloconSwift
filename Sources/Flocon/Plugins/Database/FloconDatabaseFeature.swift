import Foundation

/// Options of the database plugin.
public struct FloconDatabaseOptions {
    var databases: [FloconDatabase] = []

    /// Lists a SQLite database in the desktop app.
    public mutating func register(displayName: String, url: URL) {
        databases.append(FloconDatabase(displayName: displayName, url: url))
    }

    /// Lists a SQLite database in the desktop app.
    public mutating func register(_ database: FloconDatabase) {
        databases.append(database)
    }
}

extension FloconFeature where Options == FloconDatabaseOptions {
    /// Lists and queries the SQLite databases of the app. See ``Flocon.databasePlugin.logQuery(dbName:sqlQuery:bindArgs:)``.
    public static var database: FloconFeature<FloconDatabaseOptions> {
        .init(
            kind: .database,
            makeOptions: { FloconDatabaseOptions() },
            apply: { $0.databases.forEach(Flocon.databasePlugin.register) }
        )
    }
}

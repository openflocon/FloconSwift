import Foundation

// MARK: - From device

/// JSON format of a database in the list sent to the desktop.
struct DeviceDatabaseRemote: Encodable, Equatable {
    /// Absolute path, sent back by the desktop to query the database.
    let id: String
    let name: String
}

/// JSON format of the result of a query: `result` is itself a JSON string, see ``FloconDatabaseResult``.
struct QueryResultRemote: Encodable {
    let requestId: String
    let result: String
}

/// JSON format of a query logged by the app.
struct DatabaseQueryLogRemote: Encodable {
    /// The `id` of a database of the list.
    let dbId: String
    /// Same value as `dbId`, for the desktop apps that don't know `dbId` yet.
    let dbName: String
    let sqlQuery: String
    let bindArgs: [String]?
    /// When the query ran, in milliseconds since 1970.
    let timestamp: Int64
}

// MARK: - To device

/// Desktop request to run a query.
struct ToDeviceDatabaseQueryMessage: Decodable {
    let query: String
    let requestId: String
    /// The `id` of a database of the list.
    let database: String
}

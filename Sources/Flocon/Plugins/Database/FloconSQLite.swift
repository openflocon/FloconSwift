import Foundation
import SQLite3

/// Result of a query run from the desktop app.
enum FloconDatabaseResult: Equatable {
    /// Rows of a `SELECT`, `PRAGMA` or `EXPLAIN`; `nil` values are SQL `NULL`.
    case select(columns: [String], values: [[String?]])
    /// Row id of the row added by an `INSERT`.
    case insert(insertedId: Int64)
    /// Number of rows changed by an `UPDATE` or a `DELETE`.
    case updateDelete(affectedCount: Int)
    /// Any other statement, such as `CREATE TABLE`.
    case rawSuccess
    /// The query failed.
    case error(message: String, originalSql: String)

    /// The JSON read by the desktop: `{"type": …, "body": …}`, where `body` is itself a JSON string.
    func json() -> String {
        let type: String
        let body: [String: Any]
        switch self {
        case let .select(columns, values):
            type = "Select"
            body = ["columns": columns, "values": values.map { row in row.map { $0.map { $0 as Any } ?? NSNull() } }]
        case let .insert(insertedId):
            type = "Insert"
            body = ["insertedId": insertedId]
        case let .updateDelete(affectedCount):
            type = "UpdateDelete"
            body = ["affectedCount": affectedCount]
        case .rawSuccess:
            type = "RawSuccess"
            body = [:]
        case let .error(message, originalSql):
            type = "Error"
            body = ["message": message, "originalSql": originalSql]
        }
        return Self.string([
            "type": type,
            "body": Self.string(body),
        ])
    }

    private static func string(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Runs the queries of the desktop app on a SQLite file.
enum FloconSQLite {
    /// Size of a blob shown in the results, after which it is truncated.
    static let maxBlobBytes = 64

    /// Runs a query, chosen by its first word as on Android.
    ///
    /// The file is opened read-write but never created.
    ///
    /// - Parameters:
    ///   - query: The SQL query.
    ///   - path: Absolute path of the database file.
    /// - Returns: The result, or ``FloconDatabaseResult/error(message:originalSql:)``.
    static func execute(query: String, atPath path: String) -> FloconDatabaseResult {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open the database"
            sqlite3_close_v2(db)
            return .error(message: message, originalSql: query)
        }
        defer { sqlite3_close_v2(db) }
        // the app may be writing at the same time
        sqlite3_busy_timeout(db, 1000)

        switch firstWord(of: query) {
        case "SELECT", "PRAGMA", "EXPLAIN":
            return select(query, in: db)
        case "INSERT":
            return run(query, in: db) { .insert(insertedId: sqlite3_last_insert_rowid(db)) }
        case "UPDATE", "DELETE":
            return run(query, in: db) { .updateDelete(affectedCount: Int(sqlite3_changes(db))) }
        default:
            guard sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK else { return error(of: db, query) }
            return .rawSuccess
        }
    }

    private static func select(_ query: String, in db: OpaquePointer) -> FloconDatabaseResult {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            return error(of: db, query)
        }
        defer { sqlite3_finalize(statement) }

        let count = sqlite3_column_count(statement)
        let columns = (0..<count).map { String(cString: sqlite3_column_name(statement, $0)) }
        var rows: [[String?]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                rows.append((0..<count).map { value(of: statement, at: $0) })
            case SQLITE_DONE:
                return .select(columns: columns, values: rows)
            default:
                return error(of: db, query)
            }
        }
    }

    /// Runs a statement that returns no rows, then reads its result.
    private static func run(
        _ query: String,
        in db: OpaquePointer,
        result: () -> FloconDatabaseResult
    ) -> FloconDatabaseResult {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            return error(of: db, query)
        }
        defer { sqlite3_finalize(statement) }
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE || code == SQLITE_ROW else { return error(of: db, query) }
        return result()
    }

    private static func value(of statement: OpaquePointer, at index: Int32) -> String? {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_INTEGER:
            return String(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return String(sqlite3_column_double(statement, index))
        case SQLITE_BLOB:
            let size = Int(sqlite3_column_bytes(statement, index))
            guard size > 0, let bytes = sqlite3_column_blob(statement, index) else { return "x''" }
            return blobDescription(Data(bytes: bytes, count: size))
        default:
            guard let text = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: text)
        }
    }

    /// Hexadecimal SQL literal of a blob, truncated after ``maxBlobBytes`` bytes.
    ///
    /// For example `x'89504E47'`, or `x'89504E47…' (2048 bytes)` once truncated.
    static func blobDescription(_ data: Data) -> String {
        let hex = data.prefix(maxBlobBytes).map { String(format: "%02X", $0) }.joined()
        return data.count > maxBlobBytes ? "x'\(hex)…' (\(data.count) bytes)" : "x'\(hex)'"
    }

    private static func error(of db: OpaquePointer, _ query: String) -> FloconDatabaseResult {
        .error(message: String(cString: sqlite3_errmsg(db)), originalSql: query)
    }

    private static func firstWord(of query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix { !$0.isWhitespace && $0 != "(" }).uppercased()
    }
}

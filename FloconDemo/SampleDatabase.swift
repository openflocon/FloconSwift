import Foundation
import Flocon
import SQLite3

/// A sample SQLite database, to query from the Database section of Flocon Desktop.
enum SampleDatabase {
    static let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("dogs.sqlite")
    private static let name = "Dogs"

    /// Creates `Documents/dogs.sqlite` on the first launch, shows it in Flocon and logs the queries it runs.
    static func seed() {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            print("[FloconDemo] cannot open dogs.sqlite")
            return
        }
        defer { sqlite3_close(db) }

        // found anyway in Documents: registering it gives it a clearer name
        Flocon.databasePlugin.register(displayName: name, url: url)

        execute("CREATE TABLE IF NOT EXISTS dogs (id INTEGER PRIMARY KEY, name TEXT NOT NULL, breed TEXT, age INTEGER, weight REAL)", in: db)
        if count(in: db) == 0 {
            let dogs: [(String, String, Int, Double)] = [
                ("Rex", "German Shepherd", 4, 32.5),
                ("Médor", "Labrador", 7, 29.0),
                ("Pluto", "Bloodhound", 2, 41.2),
                ("Idéfix", "West Highland Terrier", 11, 7.8),
            ]
            dogs.forEach { insert($0, in: db) }
        }
        _ = count(in: db)
    }

    /// Inserts a random dog.
    ///
    /// - Returns: The number of dogs in the table.
    @discardableResult
    static func addDog() -> Int {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { return 0 }
        defer { sqlite3_close(db) }
        execute("CREATE TABLE IF NOT EXISTS dogs (id INTEGER PRIMARY KEY, name TEXT NOT NULL, breed TEXT, age INTEGER, weight REAL)", in: db)
        let names = ["Rex", "Médor", "Pluto", "Idéfix", "Milou", "Volt"]
        let breeds = ["Labrador", "Beagle", "Husky", "Corgi", "Poodle"]
        insert((names.randomElement()!, breeds.randomElement()!, Int.random(in: 1...15), Double.random(in: 5...40).rounded()), in: db)
        return count(in: db)
    }

    private static func execute(_ sql: String, in db: OpaquePointer?) {
        Flocon.databasePlugin.logQuery(database: url, sqlQuery: sql)
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private static func insert(_ dog: (name: String, breed: String, age: Int, weight: Double), in db: OpaquePointer?) {
        let sql = "INSERT INTO dogs (name, breed, age, weight) VALUES (?, ?, ?, ?)"
        Flocon.databasePlugin.logQuery(database: url, sqlQuery: sql, bindArgs: [dog.name, dog.breed, dog.age, dog.weight])

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        // SQLITE_TRANSIENT: SQLite copies the strings
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, dog.name, -1, transient)
        sqlite3_bind_text(statement, 2, dog.breed, -1, transient)
        sqlite3_bind_int64(statement, 3, Int64(dog.age))
        sqlite3_bind_double(statement, 4, dog.weight)
        sqlite3_step(statement)
    }

    private static func count(in db: OpaquePointer?) -> Int {
        let sql = "SELECT count(*) FROM dogs"
        Flocon.databasePlugin.logQuery(database: url, sqlQuery: sql)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int64(statement, 0)) : 0
    }
}

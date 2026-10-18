import Foundation

/// JSON format of a crash, sent to the desktop app and saved on disk until then.
struct CrashReportRemote: Codable, Equatable, Sendable {
    let crashId: String
    /// When the app crashed, in milliseconds since 1970.
    let timestamp: Int64
    /// Kind of crash: the exception name (`NSRangeException`) or the signal name (`SIGTRAP`).
    let exceptionType: String
    let exceptionMessage: String
    let stackTrace: String
}

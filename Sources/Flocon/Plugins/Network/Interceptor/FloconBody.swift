import Foundation

/// The bytes of a response body, kept to be sent to the desktop app.
struct FloconBody: Sendable {
    private(set) var data = Data()
    private(set) var totalSize: Int64 = 0

    init() {}

    init(data: Data) {
        append(data)
    }

    mutating func append(_ chunk: Data) {
        totalSize += Int64(chunk.count)
        data.append(chunk)
    }

    /// Only counts the bytes, without keeping them: for the bodies that are not sent, such as images.
    mutating func count(_ byteCount: Int) {
        totalSize += Int64(byteCount)
    }

    /// The body as UTF-8 text, or `nil` if it is not text.
    var text: String? {
        String(data: data, encoding: .utf8)
    }
}

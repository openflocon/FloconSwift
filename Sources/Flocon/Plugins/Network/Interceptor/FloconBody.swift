import Foundation

/// The bytes of a body kept to be sent to the desktop app: at most `limit` of them.
///
/// The total size is still counted, so that the desktop shows the real size of the body.
struct FloconCappedBody: Sendable {
    let limit: Int
    private(set) var data = Data()
    private(set) var totalSize: Int64 = 0

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    init(limit: Int, data: Data) {
        self.init(limit: limit)
        append(data)
    }

    var isTruncated: Bool { totalSize > Int64(data.count) }

    mutating func append(_ chunk: Data) {
        totalSize += Int64(chunk.count)
        let room = limit - data.count
        if room > 0 {
            data.append(chunk.prefix(room))
        }
    }

    /// Only counts the bytes, without keeping them: for the bodies that are not sent, such as images.
    mutating func count(_ byteCount: Int) {
        totalSize += Int64(byteCount)
    }

    /// The body as UTF-8 text, followed by a notice when it was cut, or `nil` if it is not text.
    var text: String? {
        guard isTruncated else {
            return String(data: data, encoding: .utf8)
        }
        // the cut may fall inside a UTF-8 character: drop its first bytes (at most 3)
        for dropped in 0...min(3, data.count) {
            if let text = String(data: data.dropLast(dropped), encoding: .utf8) {
                return text + "\n… [truncated by Flocon: \(totalSize) bytes in total]"
            }
        }
        return nil
    }
}

/// How the body of an intercepted request is logged and forwarded.
struct FloconRequestBody {
    /// The bytes sent to the desktop app, `nil` when the request has no body.
    let logged: FloconCappedBody?
    /// Replaces the body stream of the forwarded request: bytes when the stream fit in the
    /// limit, a temporary file holding the whole stream otherwise. `nil` keeps the request as is.
    let forwarded: Forwarded?

    enum Forwarded: Equatable {
        case data(Data)
        case file(URL)
    }

    /// Reads the body of a request, keeping at most `limit` bytes in memory.
    ///
    /// A body stream can only be read once: it is read here, and the request is forwarded with
    /// the same bytes. A stream longer than `limit` is copied to a temporary file, deleted by the
    /// caller once the request is done, instead of being loaded in memory.
    static func read(from request: URLRequest, limit: Int) -> FloconRequestBody {
        if let body = request.httpBody {
            return FloconRequestBody(logged: FloconCappedBody(limit: limit, data: body), forwarded: nil)
        }
        guard let stream = request.httpBodyStream else {
            return FloconRequestBody(logged: nil, forwarded: nil)
        }
        return read(stream: stream, limit: limit, temporaryDirectory: FileManager.default.temporaryDirectory)
    }

    static func read(stream: InputStream, limit: Int, temporaryDirectory: URL) -> FloconRequestBody {
        stream.open()
        defer { stream.close() }

        var logged = FloconCappedBody(limit: limit)
        var inMemory = Data()
        var file: (url: URL, handle: FileHandle)?

        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count <= 0 { break }
            let chunk = Data(buffer[0..<count])
            logged.append(chunk)

            if let file {
                try? file.handle.write(contentsOf: chunk)
            } else if inMemory.count + count <= limit {
                inMemory.append(chunk)
            } else if let opened = openTemporaryFile(in: temporaryDirectory) {
                // too long to stay in memory: everything goes to the file from now on
                try? opened.handle.write(contentsOf: inMemory)
                try? opened.handle.write(contentsOf: chunk)
                inMemory = Data()
                file = opened
            } else {
                // no temporary file: keep the bytes in memory, as before the limit existed
                inMemory.append(chunk)
            }
        }

        if let file {
            try? file.handle.close()
            return FloconRequestBody(logged: logged, forwarded: .file(file.url))
        }
        return FloconRequestBody(logged: logged, forwarded: .data(inMemory))
    }

    private static func openTemporaryFile(in directory: URL) -> (url: URL, handle: FileHandle)? {
        let url = directory.appendingPathComponent("flocon-body-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: url) else { return nil }
        return (url, handle)
    }
}

import Foundation

/// Uploads files to the HTTP server of the desktop app, as `multipart/form-data`.
///
/// The body is written to a temporary file and uploaded from there, so that large files are
/// never loaded in memory.
struct FloconFileUploader: Sendable {
    let host: String
    let port: Int

    /// Fields that identify the app, sent with every file.
    struct Identity: Sendable {
        let deviceId: String
        let appPackageName: String
        let appInstance: Int64
    }

    /// Session used for the uploads. Ephemeral and not intercepted by Flocon, so that uploads
    /// do not show up as network calls of the app.
    private static let session = URLSession(configuration: .ephemeral)

    func upload(fileAt fileURL: URL, remotePath: String, requestId: String, identity: Identity) async {
        guard let url = URL(string: "http://\(host):\(port)/upload") else { return }
        let boundary = "Flocon-\(UUID().uuidString)"
        let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-upload-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        do {
            try Self.writeBody(
                to: bodyURL,
                boundary: boundary,
                fields: [
                    ("remotePath", remotePath),
                    ("requestId", requestId),
                    ("deviceId", identity.deviceId),
                    ("appPackageName", identity.appPackageName),
                    ("appInstance", String(identity.appInstance)),
                ],
                fileURL: fileURL
            )

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Flocon", forHTTPHeaderField: "User-Agent")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let (_, response) = try await Self.session.upload(for: request, fromFile: bodyURL)
            if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                FloconLogger.log("Upload of \(remotePath) failed: HTTP \(status)")
            }
        } catch {
            FloconLogger.logError("Upload of \(remotePath) failed", error)
        }
    }

    /// Writes a `multipart/form-data` body: the text fields, then the file content.
    static func writeBody(to bodyURL: URL, boundary: String, fields: [(String, String)], fileURL: URL) throws {
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: bodyURL)
        defer { try? output.close() }

        func write(_ string: String) throws {
            try output.write(contentsOf: Data(string.utf8))
        }

        for (name, value) in fields {
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            try write("\(value)\r\n")
        }

        let fileName = fileURL.lastPathComponent.replacingOccurrences(of: "\"", with: "_")
        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        try write("Content-Type: application/octet-stream\r\n\r\n")

        // copy the file by chunks
        let input = try FileHandle(forReadingFrom: fileURL)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
        }

        try write("\r\n--\(boundary)--\r\n")
    }
}

import Foundation

/// Sends files to the Flocon desktop app, over its HTTP server.
protocol FloconFileSender: AnyObject, Sendable {
    /// Uploads a file to the desktop app.
    ///
    /// - Parameters:
    ///   - fileURL: The file to send.
    ///   - remotePath: Path of the file as the desktop knows it, to match the upload with its request.
    ///   - requestId: Identifier of the desktop request.
    func sendFile(at fileURL: URL, remotePath: String, requestId: String) async
}

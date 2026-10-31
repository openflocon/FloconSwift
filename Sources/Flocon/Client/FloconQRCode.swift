import Foundation

/// The address to connect to for the content of a QR code scanned by the app.
///
/// The content is either the bare address of the computer (`192.168.1.20`), or a URL whose host is that
/// address (`flocon://192.168.1.20`, `wss://my-mac.local:9023`): the scheme, the port and the path are
/// ignored, as the port is always ``FloconConfig/webSocketPort``.
///
/// Anything that is not a URL is returned trimmed and unchanged, so that ``Flocon/connect(address:)`` reports it
/// as ``FloconConnectResult/invalidAddress(_:)`` when it cannot be read.
func floconAddress(fromQRCode payload: String) -> String {
    let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.contains("://"), let host = URLComponents(string: text)?.host, !host.isEmpty else {
        return text
    }
    return host
}

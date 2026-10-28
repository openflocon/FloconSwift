import Foundation

/// Accepts the certificate of the Flocon desktop app.
///
/// The desktop serves a self-signed certificate: the connection is encrypted (so the app needs no
/// App Transport Security exception) but the certificate is not verified.
func floconServerTrustResponse(
    for challenge: URLAuthenticationChallenge
) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let trust = challenge.protectionSpace.serverTrust
    else {
        return (.performDefaultHandling, nil)
    }
    return (.useCredential, URLCredential(trust: trust))
}

/// Session delegate for the requests sent to the Flocon desktop app that are not WebSockets.
final class FloconTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = floconServerTrustResponse(for: challenge)
        completionHandler(disposition, credential)
    }
}

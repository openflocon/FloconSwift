import Foundation

extension FloconFeature where Options == FloconNetworkOptions {
    /// Sends the network calls to the desktop app, and intercepts `URLSession.shared`.
    ///
    /// Configure which requests are sent and which responses are images with ``FloconNetworkOptions``. For other sessions, see
    /// ``Foundation/URLSessionConfiguration/withFlocon()``.
    public static var network: FloconFeature<FloconNetworkOptions> {
        .init(
            kind: .network,
            makeOptions: { FloconNetworkOptions() },
            apply: { options in
                Flocon.setNetworkOptions(options)
                Flocon.interceptSharedSession()
            }
        )
    }
}

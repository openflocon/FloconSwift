import Foundation

extension FloconFeature where Options == FloconNetworkOptions {
    /// Sends the network calls to the desktop app, and intercepts `URLSession.shared`.
    ///
    /// The options are the ones of ``Flocon/setNetworkOptions(_:)``. For other sessions, see
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

import Foundation

// MARK: - Options (équivalents de shouldLog / isImage de FloconOkhttpInterceptor)

public struct FloconNetworkOptions: Sendable {
    /// Retourne false pour ne pas logger une requête.
    public var shouldLog: @Sendable (URLRequest) -> Bool
    /// Permet de dire qu'une réponse est une image en plus du test `Content-Type: image/*`.
    public var isImage: (@Sendable (URLRequest, HTTPURLResponse) -> Bool)?

    public init(
        shouldLog: @escaping @Sendable (URLRequest) -> Bool = { _ in true },
        isImage: (@Sendable (URLRequest, HTTPURLResponse) -> Bool)? = nil
    ) {
        self.shouldLog = shouldLog
        self.isImage = isImage
    }
}

private enum FloconNetworkState {
    static let lock = NSLock()
    nonisolated(unsafe) static var options = FloconNetworkOptions()
}

extension FloconNetworkOptions {
    static var current: FloconNetworkOptions {
        FloconNetworkState.lock.lock(); defer { FloconNetworkState.lock.unlock() }
        return FloconNetworkState.options
    }
}

// MARK: - API publique

extension Flocon {
    public static func setNetworkOptions(_ options: FloconNetworkOptions) {
        FloconNetworkState.lock.lock(); defer { FloconNetworkState.lock.unlock() }
        FloconNetworkState.options = options
    }

    /// Intercepte `URLSession.shared` uniquement.
    /// (Les sessions créées avec leur propre configuration utilisent `.withFlocon()`.)
    public static func interceptSharedSession() {
        URLProtocol.registerClass(FloconURLProtocol.self)
    }
}

extension URLSessionConfiguration {
    /// Usage : `URLSession(configuration: .default.withFlocon())`
    /// Avec Alamofire : `Session(configuration: URLSessionConfiguration.default.withFlocon())`
    public func withFlocon() -> URLSessionConfiguration {
        var classes = protocolClasses ?? []
        if !classes.contains(where: { $0 == FloconURLProtocol.self }) {
            classes.insert(FloconURLProtocol.self, at: 0)
        }
        protocolClasses = classes
        return self
    }
}

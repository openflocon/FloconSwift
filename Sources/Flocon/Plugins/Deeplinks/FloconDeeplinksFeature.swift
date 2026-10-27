import Foundation

/// Options of the deeplinks plugin.
public struct FloconDeeplinksOptions {
    var deeplinks: [FloconDeeplink] = []
    var variables: [FloconDeeplinkVariable] = []

    /// Lists deeplinks, and the variables they use, in the desktop app.
    public mutating func register(_ deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
        self.deeplinks += deeplinks
        self.variables += variables
    }
}

extension FloconFeature where Options == FloconDeeplinksOptions {
    /// Lists the deeplinks of the app in the desktop app, which can open them.
    public static var deeplinks: FloconFeature<FloconDeeplinksOptions> {
        .init(
            kind: .deeplinks,
            makeOptions: { FloconDeeplinksOptions() },
            apply: { Flocon.deeplinksPlugin.register(deeplinks: $0.deeplinks, variables: $0.variables) }
        )
    }
}

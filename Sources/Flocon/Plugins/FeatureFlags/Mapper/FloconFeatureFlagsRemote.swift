import Foundation

/// JSON format of the feature flags of a provider sent to the desktop app.
struct FloconFeatureFlagsRemote: Encodable {
    let provider: String
    let flags: [Flag]

    struct Flag: Encodable {
        let name: String
        let variant: String
        let payload: String?
    }

    init(provider: String, flags: [FloconFeatureFlag]) {
        self.provider = provider
        self.flags = flags.map { Flag(name: $0.name, variant: $0.variant, payload: $0.payload) }
    }
}

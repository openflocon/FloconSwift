import Foundation

/// A feature flag as evaluated by the app, shown in the Feature Flags section of the Flocon desktop app.
public struct FloconFeatureFlag: Sendable, Equatable {
    /// Key of the flag, for example `"new_checkout"`.
    public let name: String
    /// Evaluated variant, for example `"control"`, `"treatment"` or `"on"`.
    public let variant: String
    /// Optional payload attached to the variant, often json.
    public let payload: String?

    /// Creates a feature flag.
    ///
    /// - Parameters:
    ///   - name: Key of the flag.
    ///   - variant: Evaluated variant.
    ///   - payload: Optional payload attached to the variant, often json.
    public init(name: String, variant: String, payload: String? = nil) {
        self.name = name
        self.variant = variant
        self.payload = payload
    }
}

/// Registers the feature flags of a provider in the Flocon desktop app.
///
/// Use one provider per feature flag system (Firebase Remote Config, Statsig, an in-house one...).
/// Each call replaces the flags previously registered for the provider:
///
/// ```swift
/// floconFeatureFlags("firebase").register(
///     FloconFeatureFlag(name: "new_checkout", variant: "treatment", payload: #"{"color":"red"}"#),
///     FloconFeatureFlag(name: "dark_mode", variant: "on")
/// )
/// ```
public struct FloconFeatureFlags: Sendable {
    let provider: String

    /// Replaces the flags of the provider.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter flags: All the flags of the provider.
    public func register(_ flags: FloconFeatureFlag...) {
        register(flags)
    }

    /// Replaces the flags of the provider with an array of flags.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter flags: All the flags of the provider.
    public func register(_ flags: [FloconFeatureFlag]) {
        Flocon.shared.client?.featureFlagsPlugin?.register(provider: provider, flags: flags)
    }
}

/// Returns the feature flags registry of a provider.
///
/// - Parameter provider: Name of the provider, for example `"firebase"`.
/// - Returns: A registry for that provider.
public func floconFeatureFlags(_ provider: String) -> FloconFeatureFlags {
    FloconFeatureFlags(provider: provider)
}

extension Flocon {
    /// Returns the feature flags registry of a provider.
    ///
    /// - Parameter provider: Name of the provider, for example `"firebase"`.
    /// - Returns: A registry for that provider.
    public static func featureFlags(_ provider: String) -> FloconFeatureFlags {
        floconFeatureFlags(provider)
    }
}

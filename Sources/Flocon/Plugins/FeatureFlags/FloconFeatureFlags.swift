import Foundation

/// Whether a ``FloconFeatureFlag`` is on, off, or on a custom variant.
public enum FloconFeatureFlagState: String, Sendable, Equatable {
    /// The flag is on.
    case on
    /// The flag is off.
    case off
    /// Neither on nor off: an experiment arm (`"treatment"`, `"variant_b"`), a value…
    case custom
}

/// A feature flag as evaluated by the app, shown in the Feature Flags section of the Flocon desktop app.
public struct FloconFeatureFlag: Sendable, Equatable {
    /// Key of the flag, for example `"new_checkout"`.
    public let name: String
    /// Whether the flag is on, off, or on a custom variant. The desktop app colors the variant with it.
    public let state: FloconFeatureFlagState
    /// Evaluated variant, for example `"control"`, `"treatment"` or `"on"`.
    public let variant: String
    /// Optional payload attached to the variant, often json.
    public let payload: String?

    /// Creates a feature flag.
    ///
    /// - Parameters:
    ///   - name: Key of the flag.
    ///   - state: Whether the flag is on, off, or on a custom variant.
    ///   - variant: Evaluated variant.
    ///   - payload: Optional payload attached to the variant, often json.
    public init(name: String, state: FloconFeatureFlagState, variant: String, payload: String? = nil) {
        self.name = name
        self.state = state
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
/// Flocon.featureFlagsPlugin.sender("firebase").register(
///     FloconFeatureFlag(name: "new_checkout", state: .custom, variant: "treatment", payload: #"{"color":"red"}"#),
///     FloconFeatureFlag(name: "dark_mode", state: .on, variant: "on")
/// )
/// ```
public struct FloconFeatureFlags: Sendable {
    let plugin: FloconFeatureFlagsPlugin
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
        plugin.register(provider: provider, flags: flags)
    }
}

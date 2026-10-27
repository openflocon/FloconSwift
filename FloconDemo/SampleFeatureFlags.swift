import Flocon

/// Sample feature flags, shown in the Feature Flags section of Flocon Desktop.
///
/// Same flags as the Android sample: two providers, with and without payload.
enum SampleFeatureFlags {
    static func register() {
        Flocon.featureFlagsPlugin.sender("firebase").register(
            FloconFeatureFlag(name: "new_checkout", state: .custom, variant: "treatment", payload: ##"{"buttonColor":"#FF5722","steps":3}"##),
            FloconFeatureFlag(name: "dark_mode", state: .on, variant: "on"),
            FloconFeatureFlag(name: "onboarding_v2", state: .off, variant: "control")
        )
        Flocon.featureFlagsPlugin.sender("statsig").register(
            FloconFeatureFlag(name: "search_ranking", state: .custom, variant: "variant_b", payload: #"{"algorithm":"bm25","boost":{"recent":1.5,"popular":2}}"#),
            FloconFeatureFlag(name: "paywall_copy", state: .custom, variant: "short", payload: "Unlock everything")
        )
    }
}

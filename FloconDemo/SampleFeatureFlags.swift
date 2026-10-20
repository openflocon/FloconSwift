import Flocon

/// Sample feature flags, shown in the Feature Flags section of Flocon Desktop.
///
/// Same flags as the Android sample: two providers, with and without payload.
enum SampleFeatureFlags {
    static func register() {
        floconFeatureFlags("firebase").register(
            FloconFeatureFlag(name: "new_checkout", variant: "treatment", payload: ##"{"buttonColor":"#FF5722","steps":3}"##),
            FloconFeatureFlag(name: "dark_mode", variant: "on"),
            FloconFeatureFlag(name: "onboarding_v2", variant: "control")
        )
        floconFeatureFlags("statsig").register(
            FloconFeatureFlag(name: "search_ranking", variant: "variant_b", payload: #"{"algorithm":"bm25","boost":{"recent":1.5,"popular":2}}"#),
            FloconFeatureFlag(name: "paywall_copy", variant: "short", payload: "Unlock everything")
        )
    }
}

import SwiftUI

struct FeatureFlagsScreen: View {
    var body: some View {
        SampleScreenContainer(screen: .featureFlags) {
            SampleSection(title: "Flags") {
                SampleActionRow(title: "Register flags", detail: "Firebase and Statsig flags, with variants and payloads", buttonTitle: "Register") {
                    SampleFeatureFlags.register()
                    return nil
                }
            }
            SampleInfoCard(
                text: "Flags are registered when the app starts. Change their state or variant from Flocon > Feature flags, or register them again here to reset them.",
                tint: SampleTheme.accent
            )
        }
    }
}

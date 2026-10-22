import SwiftUI

struct DeeplinksScreen: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SampleScreenContainer(screen: .deeplinks) {
            SampleSection(title: "Open from the app") {
                link("flocondemo://home", detail: "Back to the home")
                link("flocondemo://user/Florent", detail: "Profile of a user")
                link("flocondemo://post/2?comment=Nice", detail: "A post with a prefilled comment")
            }
            SampleInfoCard(
                text: "The same links are listed in Flocon > Deeplinks, with their parameters. On the simulator: xcrun simctl openurl booted \"flocondemo://user/Florent\"",
                tint: SampleTheme.accent
            )
        }
    }

    private func link(_ url: String, detail: String) -> some View {
        SampleActionRow(title: url, detail: detail, buttonTitle: "Open") {
            openURL(URL(string: url)!)
            return nil
        }
    }
}

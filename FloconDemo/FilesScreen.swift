import SwiftUI

struct FilesScreen: View {
    var body: some View {
        SampleScreenContainer(screen: .files) {
            SampleSection(title: "Files") {
                SampleActionRow(title: "Write sample files", detail: "JSON, text, plist, png in Documents, Support and Caches", buttonTitle: "Write") {
                    "\(SampleFiles.seed()) files written"
                }
            }
            SampleInfoCard(
                text: "Browse, download and delete them from Flocon > Files.",
                tint: SampleTheme.accent
            )
        }
    }
}

import SwiftUI

struct DatabaseScreen: View {
    var body: some View {
        SampleScreenContainer(screen: .database) {
            SampleSection(title: "Insert rows") {
                SampleActionRow(title: "Dog", detail: "Insert a dog in dogs.sqlite", buttonTitle: "Insert") {
                    "\(SampleDatabase.addDog()) dogs"
                }
            }
            SampleInfoCard(
                text: "dogs.sqlite is created on the first launch and registered with Flocon. Open it in Flocon > Database to run queries and watch the inserted rows.",
                tint: SampleTheme.accent
            )
        }
    }
}

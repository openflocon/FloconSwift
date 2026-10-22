import SwiftUI

struct CrashScreen: View {
    var body: some View {
        SampleScreenContainer(screen: .crash) {
            SampleSection(title: "Crash") {
                SampleActionRow(title: "NSException", detail: "Index out of range", buttonTitle: "Crash", isDestructive: true) {
                    _ = NSArray().object(at: 1)
                    return nil
                }
                SampleActionRow(title: "Force unwrap of nil", detail: "Swift runtime trap", buttonTitle: "Crash", isDestructive: true) {
                    let missing = UserDefaults.standard.string(forKey: "flocon.sample.missing.key")
                    print(missing!.count)
                    return nil
                }
                SampleActionRow(title: "fatalError", detail: "Crash test from the Flocon sample", buttonTitle: "Crash", isDestructive: true) {
                    fatalError("Crash test from the Flocon sample")
                }
            }
            SampleInfoCard(
                text: "Each button crashes the app. Launch it again: the crash shows up in Flocon > Crashes. Crashes are not caught while the Xcode debugger is attached.",
                tint: SampleTheme.error
            )
        }
    }
}

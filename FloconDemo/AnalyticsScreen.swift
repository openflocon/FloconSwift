import Flocon
import SwiftUI

struct AnalyticsScreen: View {
    @State private var eventName = "clicked user"
    @State private var sentCount = 0

    var body: some View {
        SampleScreenContainer(screen: .analytics) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Compose an event")
                    .font(.headline)
                    .foregroundStyle(SampleTheme.ink)
                TextField("Event name", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Text("Sent with the properties userId = 1024 and username = florent, from the stream \"sample\".")
                    .font(.footnote)
                    .foregroundStyle(SampleTheme.inkMuted)
                Button(sentCount == 0 ? "Send event" : "Send event (\(sentCount) sent)") {
                    floconAnalytics("sample").logEvents(
                        AnalyticsEvent(
                            eventName: eventName.trimmingCharacters(in: .whitespaces),
                            AnalyticsProperty("userId", "1024"),
                            AnalyticsProperty("username", "florent")
                        )
                    )
                    sentCount += 1
                }
                .buttonStyle(SampleButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(eventName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(SampleTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SampleTheme.line))

            SampleSection(title: "Presets") {
                SampleActionRow(title: "Button tapped", detail: "One event in the stream \"sample\"", buttonTitle: "Send") {
                    floconAnalytics("sample").logEvents(
                        AnalyticsEvent(
                            eventName: "button_tapped",
                            AnalyticsProperty("screen", "AnalyticsScreen"),
                            AnalyticsProperty("id", UUID().uuidString)
                        )
                    )
                    return nil
                }
                SampleActionRow(title: "Firebase-style events", detail: "Two events from one stream", buttonTitle: "Send") {
                    floconAnalytics("firebase").logEvents(
                        AnalyticsEvent(eventName: "clicked user", AnalyticsProperty("userId", "1024"), AnalyticsProperty("username", "florent")),
                        AnalyticsEvent(eventName: "opened profile", AnalyticsProperty("userId", "2048"), AnalyticsProperty("username", "kevin"))
                    )
                    return nil
                }
            }
        }
    }
}

import Flocon
import SwiftUI

extension TimelineType {
    /// A custom type, declared once and reused.
    static let billing = TimelineType("billing")
}

struct TimelineScreen: View {
    @State private var value = "CheckoutScreen"
    @State private var tag = "network"
    @State private var taggedValue = "Request failed"
    @State private var level = TimelineLevel.error
    @State private var key1 = "sku"
    @State private var value1 = "premium_yearly"
    @State private var key2 = ""
    @State private var value2 = ""
    @State private var sentCount = 0

    private var params: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in [(key1, value1), (key2, value2)] where !key.isEmpty {
            result[key] = value
        }
        return result
    }

    private var isTextEmpty: Bool { value.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SampleScreenContainer(screen: .timeline) {
            card(title: "Typed logs (no level)") {
                TextField("Value", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                HStack {
                    Button("Navigation") { send { Flocon.timelinePlugin.logNavigation(value, params: params) } }
                    Button("User action") { send { Flocon.timelinePlugin.logUserAction(value, params: params) } }
                    Button("Lifecycle") { send { Flocon.timelinePlugin.logLifecycle(value, params: params) } }
                }
                .buttonStyle(SampleButtonStyle())
                .disabled(isTextEmpty)
                paramsFields
            }

            card(title: "Tagged log (with a level)") {
                TextField("Tag", text: $tag)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Value", text: $taggedValue)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Picker("Level", selection: $level) {
                    ForEach([TimelineLevel.debug, .info, .warning, .error], id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                Button("Send tagged log") {
                    send { Flocon.timelinePlugin.log(tag: tag, value: taggedValue, params: params, level: level) }
                }
                .buttonStyle(SampleButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(tag.trimmingCharacters(in: .whitespaces).isEmpty || taggedValue.isEmpty)
            }

            SampleSection(title: "Custom type") {
                SampleActionRow(
                    title: "TimelineType(\"billing\")",
                    detail: "A type declared once as a static constant, sent without a level",
                    buttonTitle: "Send"
                ) {
                    Flocon.timelinePlugin.log(type: .billing, value: "Purchase started", params: ["sku": "premium_yearly"])
                    return nil
                }
            }

            SampleInfoCard(
                text: "The screen changes of the sample and the scene phases are logged automatically. \(sentCount) log(s) sent from this screen.",
                tint: SampleTheme.accent
            )
        }
    }

    private var paramsFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Params (sent with the logs above, empty keys are ignored)")
                .font(.footnote)
                .foregroundStyle(SampleTheme.inkMuted)
            HStack {
                TextField("Key", text: $key1).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                TextField("Value", text: $value1).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            }
            HStack {
                TextField("Key", text: $key2).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                TextField("Value", text: $value2).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            }
        }
        .textInputAutocapitalization(.never)
    }

    private func send(_ log: () -> Void) {
        log()
        sentCount += 1
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(SampleTheme.ink)
            content()
        }
        .padding(16)
        .background(SampleTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SampleTheme.line))
    }
}

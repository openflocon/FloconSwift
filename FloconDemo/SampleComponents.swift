import SwiftUI

/// The frame shared by every plugin screen: dark background, the icon and subtitle of the plugin, then the content.
struct SampleScreenContainer<Content: View>: View {
    let screen: SampleScreen
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    SampleCategoryIcon(systemImage: screen.systemImage, category: screen.category, size: 44)
                    Text(screen.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(SampleTheme.inkMuted)
                }
                content
            }
            .padding(20)
        }
        .background(SampleTheme.bg)
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SampleCategoryIcon: View {
    let systemImage: String
    let category: SampleCategory
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.soft, in: RoundedRectangle(cornerRadius: size / 3.5))
            .accessibilityHidden(true)
    }
}

/// A card with a divider between its rows.
struct SampleCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: 0) {
                ForEach(subviews.indices, id: \.self) { index in
                    if index > 0 {
                        Divider().overlay(SampleTheme.line)
                    }
                    subviews[index]
                }
            }
        }
        .background(SampleTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SampleTheme.line))
    }
}

/// A titled card of rows.
struct SampleSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(SampleTheme.inkFaint)
                .padding(.horizontal, 4)
            SampleCard { content }
        }
    }
}

struct SampleButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isDestructive ? SampleTheme.ink : SampleTheme.onAccent)
            .frame(minWidth: 60, minHeight: 44)
            .padding(.horizontal, 12)
            .background(
                isDestructive ? SampleTheme.error.opacity(0.85) : SampleTheme.accent,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// One feature of the SDK: a title, what it does, a button, and the result (duration or error) of the last run.
struct SampleActionRow: View {
    private enum Outcome {
        case idle, running, success(String?, Int), failure(String)
    }

    let title: String
    let detail: String
    var buttonTitle = "Run"
    var isDestructive = false
    let action: () async throws -> String?

    @State private var outcome = Outcome.idle

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SampleTheme.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(SampleTheme.inkMuted)
                outcomeView
            }
            Spacer(minLength: 8)
            Button(buttonTitle, action: run)
                .buttonStyle(SampleButtonStyle(isDestructive: isDestructive))
                .disabled(isRunning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var outcomeView: some View {
        switch outcome {
        case .idle:
            EmptyView()
        case .running:
            Text("Running…").font(.footnote).foregroundStyle(SampleTheme.inkMuted)
        case .success(let result, let millis):
            Text("✓ " + [result, "\(millis) ms"].compactMap { $0 }.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(SampleTheme.success)
        case .failure(let message):
            Text("✕ \(message)").font(.footnote).foregroundStyle(SampleTheme.error)
        }
    }

    private var isRunning: Bool {
        if case .running = outcome { true } else { false }
    }

    private func run() {
        outcome = .running
        let start = ContinuousClock.now
        Task {
            do {
                let result = try await action()
                let elapsed = start.duration(to: .now)
                outcome = .success(result, Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000))
            } catch {
                outcome = .failure(error.localizedDescription)
            }
        }
    }
}

/// A small tinted note: tips, how to trigger something from the outside.
struct SampleInfoCard: View {
    let text: String
    var tint = SampleTheme.warning

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(SampleTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.33)))
    }
}

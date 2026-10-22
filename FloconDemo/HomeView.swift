import SwiftUI

/// Lists the plugins: the four main ones as tiles, the others as rows.
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("FLOCON SAMPLE")
                        .font(.footnote.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(SampleTheme.inkMuted)
                    Text("Try every plugin,\none screen each")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SampleTheme.ink)
                    Text("Trigger an action here, find it in Flocon Desktop.")
                        .font(.subheadline)
                        .foregroundStyle(SampleTheme.inkMuted)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(SampleScreen.main, id: \.self) { screen in
                        NavigationLink(value: screen) { tile(screen) }
                            .buttonStyle(.plain)
                    }
                }

                SampleSection(title: "More plugins") {
                    ForEach(SampleScreen.others, id: \.self) { screen in
                        NavigationLink(value: screen) { row(screen) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(SampleTheme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tile(_ screen: SampleScreen) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            SampleCategoryIcon(systemImage: screen.systemImage, category: screen.category, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(screen.title)
                    .font(.headline)
                    .foregroundStyle(SampleTheme.ink)
                Text(screen.subtitle)
                    .font(.caption)
                    .foregroundStyle(SampleTheme.inkMuted)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 152, maxHeight: 152, alignment: .topLeading)
        .background(SampleTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SampleTheme.line))
    }

    private func row(_ screen: SampleScreen) -> some View {
        HStack(spacing: 14) {
            SampleCategoryIcon(systemImage: screen.systemImage, category: screen.category)
            VStack(alignment: .leading, spacing: 1) {
                Text(screen.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SampleTheme.ink)
                Text(screen.subtitle)
                    .font(.footnote)
                    .foregroundStyle(SampleTheme.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SampleTheme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

import SwiftUI

/// Screens opened by the deeplinks of the sample, registered in `FloconSampleApp`.
enum DeeplinkRoute: Hashable {
    case user(id: String, url: URL)
    case post(id: String, comment: String?, url: URL)

    /// What a deeplink asks for.
    enum Destination: Equatable {
        /// `flocondemo://home`: back to the first screen.
        case home
        /// A screen to open.
        case route(DeeplinkRoute)
    }

    /// Reads a `flocondemo://` link.
    ///
    /// - Returns: The destination, or `nil` if the link is not one of the sample deeplinks.
    static func destination(for url: URL) -> Destination? {
        guard url.scheme == "flocondemo" else { return nil }
        // in flocondemo://user/Florent, "user" is the host and "/Florent" the path
        let id = url.pathComponents.dropFirst().first
        switch (url.host, id) {
        case ("home", _):
            return .home
        case ("user", let id?):
            return .route(.user(id: id, url: url))
        case ("post", let id?):
            let comment = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "comment" }?
                .value
            return .route(.post(id: id, comment: comment, url: url))
        default:
            return nil
        }
    }

    /// Readable name of the screen, for the timeline.
    var screenName: String {
        switch self {
        case .user: "User"
        case .post: "Post"
        }
    }

    /// The screen of the route.
    @ViewBuilder
    var screen: some View {
        switch self {
        case .user(let id, let url):
            UserScreen(userId: id, url: url)
        case .post(let id, let comment, let url):
            PostScreen(postId: id, comment: comment, url: url)
        }
    }
}

/// Banner showing the link that opened a screen.
struct OpenedFromDeeplinkBanner: View {
    let url: URL

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Opened from a deeplink")
                    .font(.subheadline.weight(.semibold))
                Text(url.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: "link")
                .foregroundStyle(.tint)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Profile screen, opened by `flocondemo://user/<id>`.
struct UserScreen: View {
    let userId: String
    let url: URL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OpenedFromDeeplinkBanner(url: url)

                Text(userId.prefix(2).uppercased())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(Circle().fill(Color.accentColor.gradient))

                VStack(spacing: 4) {
                    Text(userId)
                        .font(.largeTitle.bold())
                    Text("@\(userId.lowercased())")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 32) {
                    stat("Posts", "42")
                    stat("Followers", "1.2k")
                    stat("Following", "180")
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Post screen, opened by `flocondemo://post/<id>?comment=<text>`, with the comment prefilled.
struct PostScreen: View {
    let postId: String
    let url: URL
    @State private var comment: String

    init(postId: String, comment: String?, url: URL) {
        self.postId = postId
        self.url = url
        _comment = State(initialValue: comment ?? "")
    }

    var body: some View {
        Form {
            Section {
                OpenedFromDeeplinkBanner(url: url)
                    .listRowInsets(EdgeInsets())
            }

            Section("Post #\(postId)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debugging an iOS app from the desktop")
                        .font(.headline)
                    Text("Flocon shows the network calls, preferences, files and deeplinks of the app, live.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Your comment") {
                TextField("Write a comment", text: $comment, axis: .vertical)
                    .lineLimit(3...6)
                if !comment.isEmpty {
                    Label("Prefilled by the deeplink", systemImage: "text.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI
import Kingfisher

/// Images loaded by Kingfisher, hooked into Flocon in FloconSampleApp:
/// each image shows up in the images section of Flocon Desktop.
struct ImageListView: View {
    private let imageIds = Array(10..<60)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(imageIds, id: \.self) { id in
                    VStack(alignment: .leading, spacing: 4) {
                        KFImage(URL(string: "https://picsum.photos/id/\(id)/600/400"))
                            .placeholder { ProgressView() }
                            .resizable()
                            .aspectRatio(3 / 2, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("picsum #\(id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Images")
        .toolbar {
            Button("Clear cache") {
                // forces Kingfisher to download again (and so to go through Flocon again)
                KingfisherManager.shared.cache.clearMemoryCache()
                KingfisherManager.shared.cache.clearDiskCache()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImageListView()
    }
}

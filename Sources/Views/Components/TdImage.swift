import SwiftUI

struct TdImage: View {
    let fileID: Int32?
    let previewFileID: Int32?
    let previewData: Data?
    var priority: Int32 = 8
    var showsPlaceholder = true

    @EnvironmentObject var tdlib: TDLibManager
    @State private var image: UIImage?

    private var trackingID: Int32 {
        fileID ?? previewFileID ?? -1
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let previewData, let preview = UIImage(data: previewData) {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 10)
            } else {
                placeholder
            }
        }
        .clipped()
        .onAppear { load() }
        .onChange(of: tdlib.filePaths[trackingID]) { _ in
            load()
        }
    }

    private var placeholder: some View {
        ZStack {
            if showsPlaceholder {
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                Color.clear
            }
        }
    }

    private func load() {
        if image != nil { return }

        if let id = fileID, let path = tdlib.filePaths[id], let loaded = ImageCache.shared.image(at: path) {
            image = loaded
            return
        }

        if let id = previewFileID, id != fileID, let path = tdlib.filePaths[id], let loaded = ImageCache.shared.image(at: path) {
            image = loaded
            return
        }

        if let id = fileID {
            tdlib.downloadFile(id, priority: priority)
        } else if let id = previewFileID {
            tdlib.downloadFile(id, priority: priority)
        }
    }
}

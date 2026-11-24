import SwiftUI

struct TdImage: View {
    let fileID: Int32?
    let previewFileID: Int32?
    let previewData: Data?
    var priority: Int32 = 8
    var showsPlaceholder = true
    var contentMode: ContentMode = .fill
    var fallbackEmoji: String? = nil
    var maxPixels = 768
    var allowsRetry = false

    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject private var theme: ThemeManager
    @State private var decoded: UIImage?
    @State private var decodedPath: String?
    private struct Files: Equatable { let full: Int32?; let preview: Int32? }
    private struct Paths: Equatable { let full: String?; let preview: String?; let maxPixels: Int }

    private var paths: Paths {
        Paths(full: tdlib.filePath(fileID), preview: tdlib.filePath(previewFileID), maxPixels: maxPixels)
    }
    private var image: UIImage? { decodedPath == paths.full || decodedPath == paths.preview ? decoded : nil }
    private var failedID: Int32? {
        [fileID, previewFileID].compactMap { $0 }.first { tdlib.downloadErrors[$0] != nil }
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let previewData, let preview = UIImage(data: previewData) {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .blur(radius: 10)
            } else if let fallbackEmoji, !fallbackEmoji.isEmpty {
                Text(fallbackEmoji)
                    .font(.system(size: 38))
            } else {
                placeholder
            }
            if allowsRetry, let failedID, failedID == fileID || image == nil {
                Button {
                    tdlib.downloadFile(failedID, priority: priority)
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44).background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Повторить загрузку изображения")
            }
        }
        .clipped()
        .task(id: Files(full: fileID, preview: previewFileID)) {
            if let previewFileID, previewFileID != fileID, tdlib.filePath(fileID) == nil {
                tdlib.downloadFile(previewFileID, priority: priority)
            }
            if let fileID { tdlib.downloadFile(fileID, priority: priority) }
        }
        .task(id: paths) {
            let requested = paths
            for path in [requested.full, requested.preview].compactMap({ $0 }) {
                if let loaded = await ImageCache.shared.image(at: path, maxPixels: requested.maxPixels) {
                    guard !Task.isCancelled else { return }
                    decoded = loaded
                    decodedPath = path
                    return
                }
            }
            guard !Task.isCancelled else { return }
            decoded = nil
            decodedPath = nil
        }
    }

    private var placeholder: some View {
        ZStack {
            if showsPlaceholder {
                LinearGradient(
                    colors: [theme.field, theme.card],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(theme.textSecondary.opacity(0.65))
            } else {
                Color.clear
            }
        }
    }

}

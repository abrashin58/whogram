import AVKit
import SwiftUI

struct MediaViewerView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let message: RealMessage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content

            VStack {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }

                    Spacer()

                    if let path = tdlib.filePath(message.mediaFileID) {
                        ShareLink(item: URL(fileURLWithPath: path)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
            .opacity(showControls ? 1 : 0)
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            if let id = message.mediaFileID {
                tdlib.downloadFile(id, priority: 32)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.kind == .photo {
            photo
        } else if let path = tdlib.filePath(message.mediaFileID) {
            VideoPlayer(player: AVPlayer(url: URL(fileURLWithPath: path)))
                .ignoresSafeArea()
        } else {
            ZStack {
                TdImage(
                    fileID: message.mediaFileID,
                    previewFileID: message.previewFileID,
                    previewData: message.previewData,
                    priority: 32
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 2)

                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Загрузка…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.5)))
            }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let path = tdlib.filePath(message.mediaFileID),
           let image = ImageCache.shared.image(at: path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 1), 5)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = scale > 1 ? 1 : 2.4
                        lastScale = scale
                    }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                }
        } else {
            ZStack {
                TdImage(
                    fileID: message.mediaFileID,
                    previewFileID: message.previewFileID,
                    previewData: message.previewData,
                    priority: 32
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
    }
}

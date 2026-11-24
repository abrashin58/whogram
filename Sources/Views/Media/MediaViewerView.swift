import AVFoundation
import SwiftUI

struct MediaViewerView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let message: RealMessage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var showControls = true

    // Видео / аудио плеер
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress = 0.0
    @State private var durationText = "00:00"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            topBar
            controlsArea
        }
        .statusBarHidden()
        .onAppear {
            if let id = message.mediaFileID {
                tdlib.downloadFile(id, priority: 32)
            }
            setupPlayerIfNeeded()
        }
        .onChange(of: tdlib.filePaths[message.mediaFileID ?? -1]) { _ in
            setupPlayerIfNeeded()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .photo:
            photo
        case .video, .animation, .videoNote:
            videoContent
        case .audio:
            audioContent
        default:
            downloadProgress
        }
    }

    private var videoContent: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player).ignoresSafeArea()
            } else {
                TdImage(
                    fileID: message.mediaFileID,
                    previewFileID: message.previewFileID,
                    previewData: message.previewData,
                    priority: 32
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if player != nil {
                playerControls
            }

            if !message.text.isEmpty {
                captionBar
                    .padding(.top, 8)
            }
        }
    }

    private var audioContent: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player).ignoresSafeArea()
            } else {
                TdImage(
                    fileID: message.mediaFileID,
                    previewFileID: message.previewFileID,
                    previewData: message.previewData,
                    priority: 32
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(spacing: 12) {
                if let fileName = message.fileName, !fileName.isEmpty {
                    Text(fileName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                if message.fileSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: message.fileSize, countStyle: .file))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.5)))
            .padding(.horizontal, 20)
            .padding(.top, 8)

            playerControls
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

    private var downloadProgress: some View {
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
                if let fileName = message.fileName, !fileName.isEmpty {
                    Text(fileName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.5)))
        }
    }

    // MARK: - Топ-бар и элементы управления

    private var topBar: some View {
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

    private var controlsArea: some View {
        VStack {
            Spacer()
            if player != nil {
                playerControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .opacity(showControls ? 1 : 0)
    }

    private var playerControls: some View {
        HStack(spacing: 16) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            playerProgressSlider
                .frame(height: 2)

            Text(durationText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(height: 34)
        .padding(.horizontal, 8)
    }

    private var playerProgressSlider: some View {
        Slider(value: $progress, in: 0...1)
            .tint(.white.opacity(0.85))
            .onChange(of: progress) { newValue in
                guard let player = player,
                      let item = player.currentItem,
                      item.duration.isValid else { return }
                let total = CMTimeGetSeconds(item.duration)
                guard !total.isNaN, total > 0 else { return }
                player.seek(to: CMTime(seconds: total * newValue, preferredTimescale: 600))
            }
    }

    private var captionBar: some View {
        Text(message.text)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.45)))
    }

    // MARK: - Плеер

    private func setupPlayerIfNeeded() {
        guard player == nil,
              message.kind != .photo,
              let id = message.mediaFileID,
              let path = tdlib.filePath(id) else { return }

        let player = AVPlayer(url: URL(fileURLWithPath: path))
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        }
        self.player = player
        refreshPlaybackState()
    }

    private func refreshPlaybackState() {
        guard let player = player,
              let item = player.currentItem,
              item.duration.isValid else { return }

        let total = CMTimeGetSeconds(item.duration)
        guard !total.isNaN, total > 0 else { return }

        let elapsed = CMTimeGetSeconds(player.currentTime())
        progress = min(max(elapsed / total, 0), 1)
        durationText = Self.timeString(total)
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    private static func timeString(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

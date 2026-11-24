import AVKit
import Combine
import ImageIO
import QuickLook
import SwiftUI
import UIKit

struct MediaViewerView: View {
    @EnvironmentObject private var tdlib: TDLibManager
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let message: RealMessage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var showControls = true
    @State private var quickLookURL: URL?
    @State private var photoImage: UIImage?
    @State private var photoPath: String?
    @State private var photoLoadFinished = false

    private var path: String? { tdlib.filePath(message.mediaFileID) }
    private var isGIF: Bool { message.mimeType == "image/gif" || path?.lowercased().hasSuffix(".gif") == true }
    private var title: String { message.fileName.isEmpty ? message.kind.placeholder : message.fileName }

    var body: some View {
        VStack(spacing: 8) {
            if showControls { toolbar }
            content.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            if showControls && !message.text.isEmpty && message.kind != .audio && message.kind != .voice {
                ScrollView {
                    Text(message.text)
                        .font(theme.textFont)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .frame(maxHeight: 110)
                .liquidGlass(corner: theme.radius)
                .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 6)
        .background(ThemeBackdrop())
        .quickLookPreview($quickLookURL)
        .onAppear(perform: download)
        .task(id: path) {
            guard message.kind == .photo, let path else { return }
            photoPath = nil
            photoLoadFinished = false
            let loaded = await ImageCache.shared.image(at: path, maxPixels: 2560)
            guard !Task.isCancelled else { return }
            photoImage = loaded
            photoPath = path
            photoLoadFinished = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(theme.field, in: Circle())
            }
            .buttonStyle(ThemePressStyle())
            .accessibilityLabel("Закрыть")
            Spacer(minLength: 3)
            Text(title)
                .font(theme.font(14, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer(minLength: 3)
            if let path {
                ShareLink(item: URL(fileURLWithPath: path)) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                        .background(theme.field, in: Circle())
                }
                .accessibilityLabel("Поделиться файлом")
            } else {
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            }
        }
        .foregroundStyle(theme.textPrimary)
        .padding(6)
        .liquidGlass(corner: theme.radius)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let path {
            let url = URL(fileURLWithPath: path)
            switch message.kind {
            case .photo:
                photo(path)
            case .animation where isGIF:
                GIFPlayback(url: url)
            case .video, .animation, .videoNote, .audio, .voice:
                NativePlayback(url: url, message: message)
                    .id(path)
            default:
                document(url)
            }
        } else {
            downloadState
        }
    }

    @ViewBuilder
    private func photo(_ path: String) -> some View {
        if let image = photoImage, photoPath == path {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { scale = min(max(lastScale * $0, 1), 5) }
                    .onEnded { _ in lastScale = scale })
                .onTapGesture(count: 2) {
                    withAnimation(theme.animation(.spring(response: 0.3, dampingFraction: 0.8), reduced: reduceMotion)) {
                        scale = scale > 1 ? 1 : 2.4
                        lastScale = scale
                    }
                }
                .onTapGesture { showControls.toggle() }
                .accessibilityLabel("Фотография")
                .accessibilityAction(named: Text(showControls ? "Скрыть кнопки" : "Показать кнопки")) {
                    showControls.toggle()
                }
        } else if photoLoadFinished && photoPath == path {
            ThemeEmptyState(icon: "photo", title: "Не удалось открыть фото", detail: "Файл можно сохранить через кнопку «Поделиться».")
        } else {
            ProgressView("Открываем фотографию…")
        }
    }

    private func document(_ url: URL) -> some View {
        VStack(spacing: 10) {
            ThemeEmptyState(icon: "doc.fill", title: title,
                            detail: message.fileSize > 0 ? ByteCountFormatter.string(fromByteCount: message.fileSize, countStyle: .file) : "Документ Telegram")
            Button {
                quickLookURL = url
            } label: {
                Label("Открыть", systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(theme.accent.onAccent)
                    .padding(.horizontal, 15)
                    .frame(minHeight: 44)
                    .accentSurface(Capsule())
            }
            .buttonStyle(ThemePressStyle())
        }
        .padding(15)
    }

    private var downloadState: some View {
        ZStack {
            if message.previewFileID != nil || message.previewData != nil {
                TdImage(fileID: nil, previewFileID: message.previewFileID,
                        previewData: message.previewData, contentMode: .fit)
                    .opacity(0.33)
                    .accessibilityHidden(true)
            }
            if let id = message.mediaFileID {
                if let error = tdlib.downloadErrors[id] {
                    VStack(spacing: 10) {
                        ThemeEmptyState(icon: "arrow.down.circle", title: "Не удалось загрузить", detail: error)
                        Button("Повторить", action: download).frame(minHeight: 44)
                    }
                    .padding(15)
                    .liquidGlass(corner: theme.radius)
                } else {
                    VStack(spacing: 10) {
                        if let progress = tdlib.downloadProgress[id], progress > 0 {
                            ProgressView("Загрузка", value: progress)
                                .frame(width: 166)
                        } else {
                            ProgressView("Загрузка")
                        }
                    }
                    .foregroundStyle(theme.textPrimary)
                    .padding(16)
                    .liquidGlass(corner: theme.radius)
                }
            } else {
                ThemeEmptyState(icon: "doc", title: "Файл недоступен", detail: "Telegram не вернул файл для этого сообщения.")
            }
        }
    }

    private func download() {
        if let id = message.mediaFileID { tdlib.downloadFile(id, priority: 32) }
    }
}

private struct NativePlayback: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var tdlib: TDLibManager
    let url: URL
    let message: RealMessage
    @State private var player: AVPlayer?
    @State private var failure: String?
    @State private var didOpen = false

    private var audioOnly: Bool { message.kind == .audio || message.kind == .voice }

    var body: some View {
        Group {
            if let failure {
                ThemeEmptyState(icon: "play.slash", title: "Не удалось воспроизвести", detail: failure)
            } else if let player, let item = player.currentItem {
                Group {
                    if audioOnly {
                        AudioPlaybackControls(player: player, message: message)
                    } else {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius))
                            .padding(.horizontal, 10)
                    }
                }
                .onReceive(item.publisher(for: \.status, options: [.initial, .new]).receive(on: RunLoop.main)) { status in
                    if status == .failed {
                        failure = item.error?.localizedDescription ?? "Этот формат не поддерживается на устройстве."
                    }
                }
                .onReceive(player.publisher(for: \.rate, options: [.new]).receive(on: RunLoop.main)) { rate in
                    if rate > 0 && !didOpen {
                        didOpen = true
                        tdlib.markMediaOpened(message)
                    }
                }
            } else {
                ProgressView("Подготовка файла")
            }
        }
        .task(id: url) {
            AudioPlayer.shared.stop()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                player = AVPlayer(url: url)
            } catch {
                failure = error.localizedDescription
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

private struct AudioPlaybackControls: View {
    @EnvironmentObject private var theme: ThemeManager
    let player: AVPlayer
    let message: RealMessage
    @State private var elapsed = 0.0
    @State private var duration = 0.0
    @State private var editing = false
    @State private var playing = false
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: message.kind == .voice ? "waveform" : "music.note")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(theme.accent.main)
                .accessibilityHidden(true)
            Text(message.fileName.isEmpty ? "Голосовое сообщение" : message.fileName)
                .font(theme.font(19, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if !message.text.isEmpty { Text(message.text).font(theme.smallFont) }
            Button {
                if playing {
                    player.pause()
                } else {
                    if duration > 0 && elapsed >= duration - 0.1 {
                        player.seek(to: .zero)
                    }
                    player.play()
                }
                playing = player.rate > 0
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.accent.onAccent)
                    .frame(width: 56, height: 56)
                    .accentSurface(Circle())
            }
            .accessibilityLabel(playing ? "Пауза" : "Воспроизвести")
            .buttonStyle(ThemePressStyle())
            Slider(value: $elapsed, in: 0...max(duration, 1)) { editing in
                self.editing = editing
                if !editing {
                    player.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600))
                }
            }
            .disabled(duration <= 0)
            .accessibilityLabel("Позиция воспроизведения")
            HStack {
                Text(stamp(elapsed))
                Spacer()
                Text(stamp(duration > 0 ? duration : Double(message.duration)))
            }
            .font(theme.smallFont.monospacedDigit())
            .foregroundStyle(theme.textSecondary)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(18)
        .liquidGlass(corner: theme.radius)
        .padding(.horizontal, 14)
        .onReceive(timer) { _ in
            playing = player.rate > 0
            guard let total = player.currentItem?.duration.seconds, total.isFinite, total > 0 else { return }
            duration = total
            let position = player.currentTime().seconds
            if !editing && position.isFinite { elapsed = min(max(position, 0), total) }
        }
    }

    private func stamp(_ seconds: Double) -> String {
        let whole = Int(max(seconds, 0))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

private struct GIFPlayback: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false
    @State private var playing = true

    var body: some View {
        Group {
            if let image {
                VStack {
                    GIFImageView(image: image, playing: playing)
                        .accessibilityHidden(true)
                    Button(playing ? "Приостановить GIF" : "Воспроизвести GIF") { playing.toggle() }
                        .frame(minHeight: 44)
                }
            } else if failed {
                ThemeEmptyState(icon: "photo", title: "GIF не открывается", detail: "Попробуйте сохранить исходный файл.")
            } else {
                ProgressView("Подготовка GIF")
            }
        }
        .task(id: url) {
            let decoded = await Task.detached(priority: .userInitiated) { Self.decode(url) }.value
            guard !Task.isCancelled else { return }
            image = decoded
            failed = decoded == nil
        }
    }

    nonisolated private static func decode(_ url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        let step = max((count + 79) / 80, 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 360
        ]
        var frames: [UIImage] = []
        var duration = 0.0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            duration += delay.isFinite ? min(max(delay, 0.02), 10) : 0.1
            if index.isMultiple(of: step), let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) {
                frames.append(UIImage(cgImage: frame))
            }
        }
        if frames.count == 1 { return frames.first }
        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}

private struct GIFImageView: UIViewRepresentable {
    let image: UIImage
    let playing: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image.images?.first ?? image
        view.animationImages = image.images
        view.animationDuration = image.duration
        if playing && image.images != nil { view.startAnimating() } else { view.stopAnimating() }
    }
}

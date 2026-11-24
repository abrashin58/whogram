import SwiftUI
import UIKit

struct MessageBubble: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject private var audio = AudioPlayer.shared

    let message: RealMessage
    let chat: RealChat
    let showsSender: Bool
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onForward: () -> Void
    let onOpenMedia: () -> Void

    @State private var wantsPlay = false

    private var isOutgoing: Bool { message.isOutgoing }
    private var textColor: Color { isOutgoing ? theme.outgoingText : theme.textPrimary }
    private var footerColor: Color { isOutgoing ? theme.outgoingText.opacity(0.72) : theme.textSecondary }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing {
                Spacer(minLength: 46)
            } else if chat.isGroup {
                if showsSender {
                    senderAvatar
                } else {
                    Color.clear.frame(width: 30, height: 30)
                }
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if showsSender && !isOutgoing && chat.isGroup {
                    Text(senderDisplayName)
                        .font(theme.font(12, weight: .semibold))
                        .foregroundColor(theme.accent.main)
                        .padding(.leading, 6)
                        .lineLimit(1)
                }

                content

                if !message.reactions.isEmpty {
                    reactionRow
                }
            }

            if !isOutgoing {
                Spacer(minLength: 46)
            }
        }
        .contextMenu { menu }
    }

    // MARK: - Контент

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .sticker:
            stickerContent
        case .photo, .video, .animation, .videoNote:
            mediaContent
        case .voice, .audio:
            voiceContent
        case .document:
            documentContent
        case .text:
            textContent
        default:
            genericContent
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let reply = message.reply {
                replyView(reply)
            }

            if message.emojiOnly && theme.largeEmoji {
                Text(message.text)
                    .font(.system(size: 46))
                    .multilineTextAlignment(.leading)
            } else {
                Text(message.displayText)
                    .font(theme.textFont)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 280, alignment: .leading)
        .background(bubbleBackground)
    }

    private var mediaContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                TdImage(
                    fileID: message.mediaFileID,
                    previewFileID: message.previewFileID,
                    previewData: message.previewData,
                    priority: 16
                )
                .frame(width: mediaWidth, height: mediaHeight)

                if message.kind == .video || message.kind == .animation || message.kind == .videoNote {
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                if message.duration > 0 && message.kind != .photo {
                    Text(durationText)
                        .font(theme.font(10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onOpenMedia() }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(theme.textFont)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 10)
                    .padding(.top, 7)
            }

            footer
                .padding(.horizontal, 10)
                .padding(.top, 5)
                .padding(.bottom, 7)
        }
        .padding(4)
        .background(bubbleBackground)
    }

    private var stickerContent: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ZStack {
                if shouldShowStickerImage {
                    TdImage(
                        fileID: message.mediaFileID,
                        previewFileID: message.previewFileID,
                        previewData: message.previewData,
                        priority: 32,
                        showsPlaceholder: false
                    )
                    .frame(width: 158, height: 158)
                }

                if isPlayableSticker {
                    // Маркер "плей" для анимированных стикеров (как в Telegram)
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.42))
                                .frame(width: 30, height: 30)
                        )
                        .position(x: 152, y: 20)
                }

                if !message.stickerEmoji.isEmpty {
                    Text(message.stickerEmoji)
                        .font(.system(size: 92))
                        // При отображаемом изображении — тихий оверлей, иначе показываем эмодзи
                        .opacity(shouldShowStickerImage ? 0.5 : 1)
                        .shadow(color: Color.black.opacity(0.25), radius: 1.5)
                }
            }
            .frame(width: 168, height: 168)

            footer
        }
    }

    private var voiceContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reply = message.reply {
                replyView(reply)
            }

            if message.kind == .audio && !message.fileName.isEmpty {
                Text(message.fileName)
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Button {
                    toggleVoice()
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.accent.main.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: isCurrentPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.accent.main)
                    }
                }
                .buttonStyle(.plain)

                waveformView

                Text(durationText)
                    .font(theme.font(11, weight: .medium))
                    .foregroundColor(footerColor)
            }

            footer
        }
        .padding(10)
        .frame(width: 248, alignment: .leading)
        .background(bubbleBackground)
        .onChange(of: tdlib.filePaths[message.mediaFileID ?? -1]) { _ in
            onVoiceReady()
        }
    }

    private var documentContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reply = message.reply {
                replyView(reply)
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.accent.main.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.accent.main)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.fileName.isEmpty ? "Файл" : message.fileName)
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Text(fileSizeText)
                        .font(theme.captionFont)
                        .foregroundColor(footerColor)
                }

                Spacer(minLength: 6)

                fileAction
            }

            footer
        }
        .padding(10)
        .frame(width: 262, alignment: .leading)
        .background(bubbleBackground)
    }

    private var genericContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reply = message.reply {
                replyView(reply)
            }

            HStack(spacing: 8) {
                Image(systemName: iconForKind)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accent.main)

                Text(message.displayText)
                    .font(theme.textFont)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
            }

            if message.kind == .location {
                Button {
                    openMaps()
                } label: {
                    Text("Открыть в Картах")
                        .font(theme.font(12, weight: .semibold))
                        .foregroundColor(theme.accent.main)
                }
                .buttonStyle(.plain)
            }

            footer
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(bubbleBackground)
    }

    // MARK: - Элементы

    private var footer: some View {
        HStack(spacing: 4) {
            if message.views > 0 && chat.isChannel {
                Image(systemName: "eye")
                    .font(.system(size: 9, weight: .medium))
                Text("\(message.views)")
                    .font(theme.captionFont)
            }

            Text(message.formattedTime)
                .font(theme.captionFont)

            if message.isEdited {
                Text("изм.")
                    .font(theme.captionFont)
            }

            if isOutgoing {
                statusIcon
            }
        }
        .foregroundColor(footerColor)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.state {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .medium))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red)
        case .sent:
            if message.id <= chat.lastReadOutboxMessageID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
    }

    private var senderAvatar: some View {
        AvatarView(
            title: senderDisplayName,
            fileID: senderPhotoID,
            preview: senderPhotoPreview,
            size: 30
        )
    }

    private var reactionRow: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions.prefix(5)) { reaction in
                Button {
                    tdlib.toggleReaction(chatID: message.chatID, messageID: message.id, emoji: reaction.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(reaction.emoji)
                            .font(.system(size: 11))
                        if reaction.count > 1 {
                            Text("\(reaction.count)")
                                .font(theme.font(10, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(reaction.isChosen ? theme.accent.main.opacity(0.22) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                reaction.isChosen ? theme.accent.main.opacity(0.7) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .fill(barColor(index: index))
                    .frame(width: 2.5, height: max(4, 22 * bars[index]))
            }
        }
        .frame(height: 24)
    }

    private func replyView(_ reply: ReplyPreview) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isOutgoing ? theme.outgoingText.opacity(0.65) : theme.accent.main)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(replySender(reply))
                    .font(theme.font(11, weight: .semibold))
                    .foregroundColor(isOutgoing ? theme.outgoingText : theme.accent.main)
                    .lineLimit(1)
                Text(reply.text.isEmpty ? "Сообщение" : reply.text)
                    .font(theme.font(12))
                    .foregroundColor(isOutgoing ? theme.outgoingText.opacity(0.8) : theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(isOutgoing ? 0.14 : 0.06))
        )
    }

    @ViewBuilder
    private var fileAction: some View {
        if let id = message.mediaFileID, let path = tdlib.filePaths[id] {
            ShareLink(item: URL(fileURLWithPath: path)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accent.main)
            }
        } else {
            Button {
                if let id = message.mediaFileID {
                    tdlib.downloadFile(id, priority: 16)
                }
            } label: {
                if let id = message.mediaFileID, tdlib.downloading.contains(id) {
                    ProgressView()
                        .scaleEffect(0.65)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(theme.accent.main)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button {
            onReply()
        } label: {
            Label("Ответить", systemImage: "arrowshape.turn.up.left")
        }

        if message.canBeEdited {
            Button {
                onEdit()
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
        }

        if !message.text.isEmpty {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
        }

        Menu {
            ForEach(["👍", "❤️", "🔥", "😂", "😮", "😢"], id: \.self) { emoji in
                Button(emoji) {
                    tdlib.toggleReaction(chatID: message.chatID, messageID: message.id, emoji: emoji)
                }
            }
        } label: {
            Label("Реакция", systemImage: "face.smiling")
        }

        if message.canBeForwarded {
            Button {
                onForward()
            } label: {
                Label("Переслать", systemImage: "arrowshape.turn.up.right")
            }
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Удалить", systemImage: "trash")
        }
    }

    // MARK: - Вычисления

    private var bubbleFill: AnyShapeStyle {
        if isOutgoing {
            return AnyShapeStyle(theme.accent.gradient)
        }
        if theme.bubbleStyle == .glass {
            return AnyShapeStyle(Material.ultraThinMaterial)
        }
        return AnyShapeStyle(theme.incomingBubble)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: theme.bubbleCorner, style: .continuous)
            .fill(bubbleFill)
            .overlay(
                RoundedRectangle(cornerRadius: theme.bubbleCorner, style: .continuous)
                    .stroke(Color.white.opacity(theme.bubbleStyle == .glass ? 0.14 : 0), lineWidth: 1)
            )
    }

    private var mediaWidth: CGFloat {
        min(250, UIScreen.main.bounds.width * 0.62)
    }

    private var mediaHeight: CGFloat {
        guard message.mediaWidth > 0, message.mediaHeight > 0 else { return 190 }
        let ratio = CGFloat(message.mediaHeight) / CGFloat(message.mediaWidth)
        let height = mediaWidth * ratio
        return min(max(height, 120), 330)
    }

    private var durationText: String {
        let total = max(message.duration, 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var fileSizeText: String {
        guard message.fileSize > 0 else { return message.mimeType.isEmpty ? "Файл" : message.mimeType }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: message.fileSize)
    }

    private var isPlayableSticker: Bool {
        message.stickerFormat.localizedCaseInsensitiveContains("tgs")
            || message.stickerFormat.localizedCaseInsensitiveContains("webm")
    }

    /// Есть что-то, что можно показать как изображение стикера.
    private var shouldShowStickerImage: Bool {
        guard message.mediaFileID != nil else { return false }
        if isPlayableSticker {
            guard let previewFileID = message.previewFileID else { return false }
            return previewFileID != 0
        }
        return true
    }

    private var iconForKind: String {
        switch message.kind {
        case .location: return "location.fill"
        case .contact: return "person.fill"
        case .poll: return "chart.bar.fill"
        default: return "bubble.left.fill"
        }
    }

    private var isCurrentPlaying: Bool {
        audio.playingMessageID == message.id && audio.isPlaying
    }

    private var bars: [CGFloat] {
        if !message.waveform.isEmpty { return message.waveform }
        let seed = Double(message.id % 11)
        return (0..<26).map { index in
            let value = sin(Double(index) * 0.62 + seed) * 0.5 + 0.5
            return CGFloat(0.25 + value * 0.7)
        }
    }

    private func barColor(index: Int) -> Color {
        guard isCurrentPlaying else { return theme.accent.main.opacity(0.55) }
        let fraction = Double(index) / Double(max(bars.count, 1))
        return fraction <= audio.progress ? theme.accent.main : theme.textSecondary.opacity(0.35)
    }

    private var senderDisplayName: String {
        if let id = message.senderUserID, let user = tdlib.users[id] {
            return user.displayName
        }
        if let id = message.senderChatID, let chat = tdlib.chat(id) {
            return chat.title
        }
        if !message.authorSignature.isEmpty {
            return message.authorSignature
        }
        return "Участник"
    }

    private var senderPhotoID: Int32? {
        guard let id = message.senderUserID, let user = tdlib.users[id] else { return nil }
        return user.photoFileID
    }

    private var senderPhotoPreview: Data? {
        guard let id = message.senderUserID, let user = tdlib.users[id] else { return nil }
        return user.photoPreview
    }

    private func replySender(_ reply: ReplyPreview) -> String {
        guard let original = tdlib.messages[chat.id]?.first(where: { $0.id == reply.messageID }) else {
            return "Сообщение"
        }
        if let id = original.senderUserID, let user = tdlib.users[id] {
            return user.firstName
        }
        return original.isOutgoing ? "Вы" : "Собеседник"
    }

    private func toggleVoice() {
        guard let id = message.mediaFileID else { return }

        if let path = tdlib.filePaths[id] {
            audio.toggle(messageID: message.id, url: URL(fileURLWithPath: path))
            return
        }

        wantsPlay = true
        tdlib.downloadFile(id, priority: 32)
    }

    private func openMaps() {
        let urlString = "http://maps.apple.com/?ll=\(message.latitude),\(message.longitude)"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func onVoiceReady() {
        guard wantsPlay,
              let id = message.mediaFileID,
              let path = tdlib.filePaths[id] else { return }
        wantsPlay = false
        audio.play(messageID: message.id, url: URL(fileURLWithPath: path))
    }
}

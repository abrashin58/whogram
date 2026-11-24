import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatDetailView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let chat: RealChat

    @State private var text = ""
    @State private var replyTo: RealMessage?
    @State private var editing: RealMessage?
    @State private var showStickers = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showInfo = false
    @State private var showClearConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: RealMessage?
    @State private var forwardTarget: RealMessage?
    @State private var viewerMessage: RealMessage?
    @State private var showChatSearch = false
    @State private var searchQuery = ""
    @FocusState private var inputFocused: Bool
    @ObservedObject private var voiceRecorder = VoiceRecorder.shared

    private var liveChat: RealChat {
        tdlib.chats.first(where: { $0.id == chat.id }) ?? chat
    }

    private var messages: [RealMessage] {
        tdlib.messages[chat.id] ?? []
    }

    private var days: [MessageDay] {
        MessageDay.group(messages)
    }

    private var typingText: String? {
        tdlib.typing[chat.id]
    }

    var body: some View {
        ZStack {
            WallpaperView()

            VStack(spacing: 0) {
                header

                if showChatSearch {
                    searchBar
                }

                if showChatSearch && !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
                    messagesList
                }

                if let typingText {
                    HStack(spacing: 6) {
                        Text(typingText)
                            .font(theme.font(11))
                            .foregroundColor(.white.opacity(0.75))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 2)
                }

                if showStickers {
                    StickerPanel(
                        onSticker: { sticker in
                            tdlib.sendSticker(sticker, chatID: chat.id, replyTo: replyTo?.id)
                            replyTo = nil
                        },
                        onEmoji: { emoji in
                            text += emoji
                            inputFocused = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                composer
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            tdlib.openChat(chat.id)
            tdlib.markAsRead(liveChat)
        }
        .onDisappear {
            tdlib.closeChat(chat.id)
            if voiceRecorder.isRecording {
                voiceRecorder.cancel()
            }
        }
        .onChange(of: messages.count) { _ in
            tdlib.markAsRead(liveChat)
        }
        .sheet(isPresented: $showInfo) {
            ChatInfoView(chat: liveChat)
        }
        .sheet(item: $viewerMessage) { message in
            MediaViewerView(message: message)
        }
        .sheet(item: $forwardTarget) { message in
            ChatPickerView(title: "Переслать") { target in
                tdlib.forwardMessage(chatID: chat.id, messageID: message.id, to: target.id)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await sendPhoto(item) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Очистить историю?", isPresented: $showClearConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Очистить", role: .destructive) {
                tdlib.clearHistory(liveChat)
            }
        } message: {
            Text("Сообщения будут удалены только у вас.")
        }
        .confirmationDialog(
            "Удалить сообщение?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить у всех", role: .destructive) {
                if let target = deleteTarget {
                    tdlib.deleteMessage(chatID: chat.id, messageID: target.id)
                }
                deleteTarget = nil
            }
            Button("Отмена", role: .cancel) {
                deleteTarget = nil
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(theme.card.opacity(0.7)))
            }
            .buttonStyle(.plain)

            Button {
                showInfo = true
            } label: {
                HStack(spacing: 10) {
                    AvatarView(
                        title: liveChat.title,
                        fileID: avatarFileID,
                        preview: avatarPreview,
                        size: 38,
                        isOnline: isOnline
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(liveChat.title)
                                .font(theme.font(16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)

                            if liveChat.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.accent.main)
                            }
                        }

                        Text(headerSubtitle)
                            .font(theme.font(11))
                            .foregroundColor(typingText == nil ? theme.textSecondary : theme.accent.main)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChatSearch.toggle()
                }
                if !showChatSearch {
                    searchQuery = ""
                    tdlib.clearMessageSearch()
                }
            } label: {
                headerIcon(showChatSearch ? "xmark" : "magnifyingglass")
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    showInfo = true
                } label: {
                    Label("Информация", systemImage: "info.circle")
                }

                Button {
                    tdlib.togglePin(liveChat)
                } label: {
                    Label(liveChat.isPinned ? "Открепить" : "Закрепить", systemImage: "pin")
                }

                Button {
                    tdlib.toggleMute(liveChat)
                } label: {
                    Label(liveChat.isMuted ? "Включить звук" : "Без звука", systemImage: liveChat.isMuted ? "bell.fill" : "bell.slash.fill")
                }

                Button {
                    tdlib.markAsRead(liveChat)
                } label: {
                    Label("Отметить прочитанным", systemImage: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Очистить историю", systemImage: "trash")
                }
            } label: {
                headerIcon("ellipsis")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.background.opacity(0.92))
    }

    private func headerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .frame(width: 34, height: 34)
            .background(Circle().fill(theme.card.opacity(0.7)))
    }

    private var headerSubtitle: String {
        if let typingText { return typingText }
        if liveChat.isPrivate {
            if let user = tdlib.user(liveChat.userID) {
                return user.statusText
            }
            return "личный чат"
        }
        if liveChat.isChannel { return liveChat.subtitle }
        if liveChat.isGroup { return liveChat.subtitle }
        return liveChat.kindTitle
    }

    private var avatarFileID: Int32? {
        liveChat.photoFileID ?? tdlib.user(liveChat.userID)?.photoFileID
    }

    private var avatarPreview: Data? {
        liveChat.photoPreview ?? tdlib.user(liveChat.userID)?.photoPreview
    }

    private var isOnline: Bool {
        tdlib.user(liveChat.userID)?.isOnline ?? false
    }

    // MARK: - Сообщения

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    if messages.count >= 40 {
                        Button {
                            tdlib.loadMoreMessages(chatID: chat.id)
                        } label: {
                            Text("Загрузить ещё")
                                .font(theme.font(12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 4)
                    }

                    if messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 34, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Здесь пока нет сообщений")
                                .font(theme.font(13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 80)
                    }

                    ForEach(days) { day in
                        Text(DateFormatters.dayTitle(day.date))
                            .font(theme.font(11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.28)))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)

                        ForEach(day.messages.indices, id: \.self) { index in
                            let message = day.messages[index]
                            bubble(for: message, showsSender: showsSender(message, index: index, in: day))
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 4)
                        .id("bottom")
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy, animated: true)
            }
        }
    }

    private func bubble(for message: RealMessage, showsSender: Bool) -> some View {
        MessageBubble(
            message: message,
            chat: liveChat,
            showsSender: showsSender,
            onReply: {
                replyTo = message
                editing = nil
                inputFocused = true
            },
            onEdit: {
                editing = message
                replyTo = nil
                text = message.text
                inputFocused = true
            },
            onDelete: {
                deleteTarget = message
                showDeleteConfirm = true
            },
            onForward: {
                forwardTarget = message
            },
            onOpenMedia: {
                viewerMessage = message
            }
        )
    }

    private func showsSender(_ message: RealMessage, index: Int, in day: MessageDay) -> Bool {
        guard !message.isOutgoing, liveChat.isGroup else { return false }
        guard index > 0 else { return true }
        let previous = day.messages[index - 1]
        if previous.senderUserID != message.senderUserID { return true }
        return message.date - previous.date > 300
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if animated {
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Поиск

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            TextField("Поиск в чате", text: $searchQuery)
                .font(theme.font(14))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .onChange(of: searchQuery) { value in
                    if value.trimmingCharacters(in: .whitespaces).isEmpty {
                        tdlib.clearMessageSearch()
                    } else {
                        tdlib.searchMessages(chatID: chat.id, query: value)
                    }
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    tdlib.clearMessageSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Button("Отмена") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChatSearch = false
                }
                searchQuery = ""
                tdlib.clearMessageSearch()
            }
            .font(theme.font(12, weight: .semibold))
            .foregroundColor(theme.accent.main)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if tdlib.messageSearchResults.isEmpty {
                    Text("Ничего не найдено")
                        .font(theme.font(13))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 40)
                }

                ForEach(tdlib.messageSearchResults) { message in
                    Button {
                        showChatSearch = false
                        searchQuery = ""
                        tdlib.clearMessageSearch()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.displayText)
                                .font(theme.font(14))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(message.formattedTime)
                                .font(theme.font(11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.card.opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Поле ввода

    private var composer: some View {
        VStack(spacing: 0) {
            if voiceRecorder.isRecording {
                voiceRecordingIndicator
            }

            if let replyTo {
                replyBanner(replyTo, isEditing: false)
            }
            if let editing {
                replyBanner(editing, isEditing: true)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Фото из галереи", systemImage: "photo")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Файл", systemImage: "doc")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStickers.toggle()
                        }
                    } label: {
                        Label("Стикеры", systemImage: "face.smiling")
                    }
                } label: {
                    composerIcon("plus")
                }

                HStack(alignment: .bottom, spacing: 8) {
                TextField("Сообщение…", text: $text)
                    .font(theme.textFont)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: text) { value in
                        if !value.isEmpty && editing == nil {
                            tdlib.sendTyping(chatID: chat.id)
                        }
                    }

                    Button {
                        toggleVoiceRecording()
                    } label: {
                        Image(systemName: voiceRecorder.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(voiceRecorder.isRecording ? .red : theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStickers.toggle()
                        }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.field)
                )

                Button {
                    sendText()
                } label: {
                    Image(systemName: editing == nil ? "arrow.up" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.accent.onAccent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(theme.accent.gradient))
                        .opacity(canSend ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(theme.background.opacity(0.94))
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Голосовое сообщение

    private func toggleVoiceRecording() {
        if voiceRecorder.isRecording {
            voiceRecorder.stop()
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).wav")
            VoiceRecorder.shared.start(url: url) { draft in
                tdlib.sendVoiceNote(chatID: chat.id, draft: draft, replyTo: replyTo?.id)
                replyTo = nil
            }
        }
    }

    private var voiceRecordingIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.red)

            Text(String(format: "%02d:%02d", Int(voiceRecorder.duration) / 60, Int(voiceRecorder.duration) % 60))
                .font(theme.font(12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .frame(width: 42, alignment: .leading)

            Spacer()

            Button {
                voiceRecorder.cancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func composerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .frame(width: 36, height: 36)
            .background(Circle().fill(theme.field))
    }

    private func replyBanner(_ message: RealMessage, isEditing: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.accent.main)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Редактирование" : "Ответ на сообщение")
                    .font(theme.font(11, weight: .semibold))
                    .foregroundColor(theme.accent.main)
                Text(message.previewText)
                    .font(theme.font(12))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                replyTo = nil
                editing = nil
                if isEditing { text = "" }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.elevated)
    }

    // MARK: - Действия

    private func sendText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let editing {
            tdlib.editMessage(chatID: chat.id, messageID: editing.id, text: trimmed)
            self.editing = nil
        } else {
            tdlib.sendMessage(chatID: chat.id, text: trimmed, replyTo: replyTo?.id)
            replyTo = nil
        }

        text = ""
        inputFocused = false
    }

    private func sendPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            photoItem = nil
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whogram-\(UUID().uuidString).jpg")

        do {
            try data.write(to: url)
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)
            tdlib.sendPhoto(
                chatID: chat.id,
                path: url.path,
                width: width,
                height: height,
                replyTo: replyTo?.id
            )
            replyTo = nil
        } catch {
            tdlib.errorMessage = "Не удалось отправить фото"
        }

        photoItem = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.copyItem(at: url, to: destination)
            tdlib.sendDocument(chatID: chat.id, path: destination.path, replyTo: replyTo?.id)
            replyTo = nil
        } catch {
            tdlib.errorMessage = "Не удалось отправить файл"
        }
    }
}

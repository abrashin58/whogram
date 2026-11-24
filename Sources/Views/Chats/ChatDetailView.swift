import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatDetailView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var searchTarget: Int64?
    @State private var olderSearchResult: RealMessage?
    @State private var stickerPack: StickerPackLink?
    @State private var atLatest = true
    @State private var nearHistoryStart = false
    @State private var historyAnchor: Int64?
    @State private var didPositionHistory = false
    @FocusState private var inputFocused: Bool
    @StateObject private var voiceRecorder = VoiceRecorder()

    private struct StickerPackLink: Identifiable { let id: Int64 }
    private var transitionAnimation: Animation? {
        theme.animation(.spring(response: 0.32, dampingFraction: 0.88), reduced: reduceMotion)
    }

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
            WallpaperView().ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if showChatSearch {
                    searchBar
                }

                if let olderSearchResult {
                    searchResultPreview(olderSearchResult)
                } else if showChatSearch && !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
                    messagesList
                }

                if let typingText {
                    HStack(spacing: 6) {
                        Text(typingText)
                            .font(theme.font(11))
                            .foregroundColor(theme.textSecondary)
                            .padding(5)
                            .background(theme.card, in: Capsule())
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 2)
                }

                if showStickers {
                    StickerPanel(
                        onSticker: { sticker in
                            sendSticker(sticker)
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
            tdlib.clearMessageSearch()
            voiceRecorder.cancel()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { voiceRecorder.cancel() }
        }
        .onChange(of: voiceRecorder.error) { error in
            if let error { tdlib.errorMessage = error }
        }
        .onChange(of: messages.count) { _ in
            if atLatest { tdlib.markAsRead(liveChat) }
        }
        .sheet(isPresented: $showInfo) {
            ChatInfoView(chat: liveChat)
        }
        .sheet(item: $viewerMessage) { message in
            MediaViewerView(message: message)
        }
        .sheet(item: $stickerPack) { pack in
            StickerPackView(setID: pack.id, onSticker: sendSticker)
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
            .buttonStyle(ThemePressStyle())
            .accessibilityLabel("Назад")

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
                olderSearchResult = nil
                withAnimation(transitionAnimation) {
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
            .accessibilityLabel(showChatSearch ? "Закрыть поиск" : "Поиск в чате")

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
            .accessibilityLabel("Действия чата")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlass(corner: theme.radius)
        .padding(.horizontal, 8)
        .padding(.top, 3)
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
                LazyVStack(spacing: theme.compact ? 3 : 7) {
                    if messages.contains(where: { $0.id > 0 }) && !tdlib.exhaustedHistory.contains(chat.id) {
                        Button {
                            requestOlder()
                        } label: {
                            Group {
                                if tdlib.loadingHistory.contains(chat.id) {
                                    ProgressView()
                                } else {
                                    Text(tdlib.historyErrors[chat.id] == nil ? "Более ранние сообщения" : "Повторить загрузку")
                                        .font(theme.font(12, weight: .semibold))
                                }
                            }
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(theme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(tdlib.loadingHistory.contains(chat.id))
                        .padding(.bottom, 4)
                        .background {
                            GeometryReader { row in
                                Color.clear.preference(key: HistoryEdges.self, value: [
                                    "start": row.frame(in: .named("history")).maxY
                                ])
                            }
                        }
                    }

                    if let error = tdlib.historyErrors[chat.id] {
                        VStack(spacing: 8) {
                            Text("Не удалось загрузить историю").font(theme.textFont)
                            Text(error).font(theme.smallFont).foregroundStyle(theme.textSecondary)
                            if messages.isEmpty || tdlib.exhaustedHistory.contains(chat.id) {
                                Button("Повторить") { tdlib.refreshHistory(chatID: chat.id) }
                                    .frame(minHeight: 44)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(12)
                    }

                    if messages.isEmpty {
                        if tdlib.loadingHistory.contains(chat.id) {
                            ChatSkeleton(count: 4)
                        } else if tdlib.historyErrors[chat.id] == nil {
                            ThemeEmptyState(icon: "bubble.left.and.bubble.right", title: "Здесь пока тихо",
                                            detail: "В этом чате пока нет сообщений.")
                                .padding(.top, 64)
                        }
                    }

                    ForEach(days) { day in
                        Text(DateFormatters.dayTitle(day.date))
                            .font(theme.font(11, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(theme.card))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)

                        ForEach(Array(day.messages.enumerated()), id: \.element.id) { index, message in
                            bubble(for: message, showsSender: showsSender(message, index: index, in: day))
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 4)
                        .id("bottom")
                        .background {
                            GeometryReader { row in
                                Color.clear.preference(key: HistoryEdges.self, value: [
                                    "end": row.frame(in: .named("history")).maxY
                                ])
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .coordinateSpace(name: "history")
            .background {
                GeometryReader { viewport in
                    Color.clear.preference(key: HistoryEdges.self, value: ["height": viewport.size.height])
                }
            }
            .onPreferenceChange(HistoryEdges.self) { edges in
                guard let height = edges["height"], height > 0 else { return }
                atLatest = edges["end"].map { $0 <= height + 40 } ?? messages.isEmpty
                let nearTop = edges["start"].map { $0 >= -48 && $0 <= height } ?? false
                if nearTop && !nearHistoryStart && !atLatest && didPositionHistory && tdlib.historyErrors[chat.id] == nil {
                    requestOlder()
                }
                nearHistoryStart = nearTop
            }
            .overlay(alignment: .bottomTrailing) {
                if !atLatest && !messages.isEmpty {
                    Button { scrollToBottom(proxy, animated: true) } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.accent.onAccent)
                            .frame(width: 44, height: 44)
                            .accentSurface(Circle())
                    }
                    .buttonStyle(ThemePressStyle())
                    .accessibilityLabel("К последним сообщениям")
                    .padding(12)
                }
            }
            .onAppear {
                if let target = searchTarget {
                    searchTarget = nil
                    DispatchQueue.main.async { proxy.scrollTo(target, anchor: .center) }
                } else {
                    scrollToBottom(proxy, animated: false)
                }
            }
            .onChange(of: messages.last?.id) { newID in
                guard newID != nil else { return }
                if !didPositionHistory || atLatest { scrollToBottom(proxy, animated: didPositionHistory) }
            }
            .onChange(of: atLatest) { latest in
                if latest { tdlib.markAsRead(liveChat) }
            }
            .onChange(of: tdlib.loadingHistory.contains(chat.id)) { loading in
                guard !loading, let anchor = historyAnchor else { return }
                historyAnchor = nil
                if messages.first?.id != anchor, messages.contains(where: { $0.id == anchor }) {
                    DispatchQueue.main.async { proxy.scrollTo(anchor, anchor: .top) }
                }
            }
        }
    }

    private struct HistoryEdges: PreferenceKey {
        static let defaultValue: [String: CGFloat] = [:]
        static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, newer in newer })
        }
    }

    private func requestOlder() {
        guard !tdlib.loadingHistory.contains(chat.id), let first = messages.first?.id else { return }
        historyAnchor = first
        tdlib.loadMoreMessages(chatID: chat.id)
    }

    private func bubble(for message: RealMessage, showsSender: Bool) -> some View {
        MessageBubble(
            message: message,
            chat: liveChat,
            showsSender: showsSender,
            onReply: {
                olderSearchResult = nil
                replyTo = message
                editing = nil
                inputFocused = true
            },
            onEdit: {
                olderSearchResult = nil
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
            },
            onOpenStickerPack: {
                if let id = message.stickerSetID { stickerPack = StickerPackLink(id: id) }
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
        DispatchQueue.main.async {
            if animated {
                withAnimation(transitionAnimation) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            if !messages.isEmpty { didPositionHistory = true }
        }
    }

    // MARK: - Поиск

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            TextField("Поиск в чате", text: $searchQuery)
                .font(theme.font(14))
                .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Button("Отмена") {
                withAnimation(transitionAnimation) {
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
        .liquidGlass(corner: theme.radius)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if tdlib.messageSearchResults.isEmpty {
                    Text("Ничего не найдено")
                        .font(theme.font(13))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 40)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                }

                ForEach(tdlib.messageSearchResults) { message in
                    Button {
                        if messages.contains(where: { $0.id == message.id }) {
                            searchTarget = message.id
                        } else {
                            olderSearchResult = message
                        }
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

    private func searchResultPreview(_ message: RealMessage) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Label("Результат поиска", systemImage: "magnifyingglass")
                        .font(theme.font(13, weight: .semibold))
                    Spacer()
                    Button("К переписке") { olderSearchResult = nil }
                        .font(theme.smallFont)
                        .frame(minHeight: 44)
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .liquidGlass(corner: theme.radius)
                bubble(for: message, showsSender: liveChat.isGroup)
            }
            .padding(10)
        }
    }

    // MARK: - Поле ввода

    private var composer: some View {
        VStack(spacing: 0) {
            if let replyTo {
                replyBanner(replyTo, isEditing: false)
            }
            if let editing {
                replyBanner(editing, isEditing: true)
            }

            if voiceRecorder.isRecording {
                recordingControls
            } else {
                composerInput
            }
        }
        .liquidGlass(corner: theme.composerRadius)
        .disabled(!tdlib.isSessionReady)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var composerInput: some View {
            HStack(alignment: .bottom, spacing: 6) {
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
                        toggleStickers()
                    } label: {
                        Label("Стикеры", systemImage: "face.smiling")
                    }
                } label: {
                    composerIcon("plus")
                }
                .accessibilityLabel("Вложения")

                HStack(alignment: .bottom, spacing: 5) {
                TextField("Сообщение…", text: $text, axis: .vertical)
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
                        toggleStickers()
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .frame(minWidth: 36, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Стикеры и эмодзи")
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .frame(minHeight: theme.composerControl)
                .background(
                    RoundedRectangle(cornerRadius: theme.composerRadius, style: .continuous)
                        .fill(theme.field)
                )

                Button {
                    if canSend {
                        sendText()
                    } else {
                        inputFocused = false
                        showStickers = false
                        voiceRecorder.start()
                    }
                } label: {
                    Image(systemName: canSend ? (editing == nil ? "arrow.up" : "checkmark") : "mic")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.accent.onAccent)
                        .frame(width: theme.composerControl, height: theme.composerControl)
                        .accentSurface(Circle())
                }
                .buttonStyle(ThemePressStyle())
                .accessibilityLabel(canSend ? (editing == nil ? "Отправить" : "Сохранить правку") : "Записать голосовое")
                .disabled(voiceRecorder.isPreparing || (editing != nil && !canSend))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var recordingControls: some View {
        HStack(spacing: 8) {
            Button { voiceRecorder.cancel() } label: {
                composerIcon("xmark")
            }
            .buttonStyle(ThemePressStyle())
            .accessibilityLabel("Отменить запись")
            Label(String(format: "%02d:%02d", Int(voiceRecorder.duration) / 60, Int(voiceRecorder.duration) % 60),
                  systemImage: "waveform")
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .accessibilityLabel("Идёт запись")
            Spacer()
            Button {
                guard let draft = voiceRecorder.finish() else { return }
                tdlib.sendVoiceNote(chatID: chat.id, draft: draft, replyTo: replyTo?.id)
                replyTo = nil
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: theme.composerControl, height: theme.composerControl)
                    .foregroundStyle(theme.accent.onAccent)
                    .accentSurface(Circle())
            }
            .buttonStyle(ThemePressStyle())
            .accessibilityLabel("Отправить голосовое")
        }
        .padding(9)
    }

    private func toggleStickers() {
        if !showStickers { inputFocused = false }
        withAnimation(transitionAnimation) { showStickers.toggle() }
    }

    private func sendSticker(_ sticker: RealSticker) {
        tdlib.sendSticker(sticker, chatID: chat.id, replyTo: replyTo?.id)
        replyTo = nil
        withAnimation(transitionAnimation) { showStickers = false }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func composerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .frame(width: 44, height: 44)
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
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.90) else {
            tdlib.errorMessage = "Не удалось открыть выбранное фото"
            photoItem = nil
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whogram-\(UUID().uuidString).jpg")

        do {
            try jpeg.write(to: url, options: .atomic)
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

        let stagingFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("whogram-upload-\(UUID().uuidString)", isDirectory: true)
        let destination = stagingFolder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
            tdlib.sendDocument(chatID: chat.id, path: destination.path, replyTo: replyTo?.id)
            replyTo = nil
        } catch {
            try? FileManager.default.removeItem(at: stagingFolder)
            tdlib.errorMessage = "Не удалось отправить файл"
        }
    }
}

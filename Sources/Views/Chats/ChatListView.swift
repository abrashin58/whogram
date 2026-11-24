import SwiftUI

enum ChatFolder: String, CaseIterable, Identifiable {
    case all
    case unread
    case personal
    case groups
    case channels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Все"
        case .unread: return "Непрочитанные"
        case .personal: return "Личные"
        case .groups: return "Группы"
        case .channels: return "Каналы"
        }
    }

    func matches(_ chat: RealChat) -> Bool {
        switch self {
        case .all: return true
        case .unread: return chat.unreadCount > 0 || chat.isMarkedAsUnread
        case .personal: return !chat.isGroup && !chat.isChannel
        case .groups: return chat.isGroup
        case .channels: return chat.isChannel
        }
    }
}

struct ChatListView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var path: NavigationPath
    var onOpenSettings: () -> Void

    @State private var searchText = ""
    @State private var folder: ChatFolder = .all
    @State private var clearTarget: RealChat?
    @State private var showClearConfirm = false
    @State private var showRadar = false
    @State private var radarChatID: Int64?
    @State private var radarTurn = 0.0

    private var radarCandidates: [RealChat] { tdlib.mainChats.filter(ChatFolder.unread.matches) }

    private var filteredChats: [RealChat] {
        tdlib.mainChats.filter { chat in
            folder.matches(chat) &&
            (searchText.isEmpty || chat.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var totalUnread: Int {
        tdlib.mainChats.reduce(0) { result, chat in
            result + (chat.isMuted ? 0 : chat.unreadCount)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ThemeBackdrop()

                VStack(spacing: 0) {
                    header
                    searchField
                    folderBar

                    if tdlib.isLoadingChats && tdlib.mainChats.isEmpty {
                        ScrollView { ChatSkeleton(count: 6).padding(14) }
                    } else if filteredChats.isEmpty {
                        emptyState
                    } else {
                        chatsList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRadar) { unreadRadar }
            .navigationDestination(for: Int64.self) { id in
                if let chat = tdlib.chats.first(where: { $0.id == id }) {
                    ChatDetailView(chat: chat)
                } else {
                    ZStack {
                        ThemeBackdrop()
                        Text("Чат не найден")
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .alert("Очистить историю?", isPresented: $showClearConfirm) {
                Button("Отмена", role: .cancel) {
                    clearTarget = nil
                }
                Button("Очистить", role: .destructive) {
                    if let clearTarget {
                        tdlib.clearHistory(clearTarget)
                    }
                    clearTarget = nil
                }
            } message: {
                Text("Сообщения будут удалены только у вас.")
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Чаты")
                    .font(theme.font(34, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(headerSubtitle)
                    .font(theme.font(12))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            if !radarCandidates.isEmpty {
                Button {
                    radarChatID = radarCandidates.first(where: { !$0.isMuted })?.id ?? radarCandidates.first?.id
                    radarTurn = 0
                    showRadar = true
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 21, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent.main)
                .accessibilityLabel("Радар непрочитанных")
            }

            Button {
                onOpenSettings()
            } label: {
                AvatarView(
                    title: meName,
                    fileID: tdlib.me?.photoFileID,
                    preview: tdlib.me?.photoPreview,
                    size: 44,
                    highlight: true
                )
            }
            .buttonStyle(ThemePressStyle())
            .accessibilityLabel("Профиль и настройки")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var unreadRadar: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().strokeBorder(theme.accent.main.opacity(0.25), lineWidth: 1)
                Circle().trim(from: 0, to: 0.26)
                    .stroke(theme.accent.main, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(radarTurn - 90))
                Image(systemName: "scope")
                    .font(.system(size: 29))
                    .foregroundStyle(theme.accent.main)
            }
            .frame(width: 86, height: 86)
            .accessibilityHidden(true)

            Text("Радар непрочитанных").font(theme.font(22, weight: .bold))
            if let chat = radarCandidates.first(where: { $0.id == radarChatID }) {
                Text(chat.title).font(theme.font(16, weight: .semibold)).lineLimit(2)
                Text(chat.unreadCount > 0 ? "\(chat.unreadCount) · непрочитанные" : "Отмечен как непрочитанный")
                    .font(theme.smallFont)
                    .foregroundStyle(theme.textSecondary)
                Button("Открыть чат") {
                    showRadar = false
                    path.append(chat.id)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Среди загруженных чатов нет выбранного непрочитанного.")
                    .font(theme.smallFont)
            }
            if radarCandidates.contains(where: { $0.id != radarChatID }) {
                Button("Другой сигнал") {
                    let next = radarCandidates.filter { $0.id != radarChatID }.randomElement()
                    radarChatID = next?.id
                    withAnimation(theme.animation(.spring(response: 0.58, dampingFraction: 0.73), reduced: reduceMotion)) {
                        if theme.animations && !reduceMotion { radarTurn += 225 }
                    }
                }
                .frame(minHeight: 44)
            }
            Button("Закрыть") { showRadar = false }.frame(minHeight: 44)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackdrop())
    }

    private var headerSubtitle: String {
        if totalUnread > 0 {
            return "\(totalUnread) \(unreadWord(totalUnread))"
        }
        if tdlib.isLoadingChats && tdlib.mainChats.isEmpty {
            return "Загрузка чатов…"
        }
        if tdlib.mainChats.isEmpty { return "Telegram" }
        return "Все сообщения прочитаны"
    }

    private var meName: String {
        tdlib.me?.displayName ?? "Профиль"
    }

    private func unreadWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "новое сообщение" }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return "новых сообщения" }
        return "новых сообщений"
    }

    // MARK: - Поиск и папки

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            TextField("Поиск", text: $searchText)
                .font(theme.font(14))
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.field)
        )
        .padding(.horizontal, 18)
    }

    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFolder.allCases) { item in
                    Button {
                        withAnimation(theme.animation(.easeOut(duration: 0.18), reduced: reduceMotion)) {
                            folder = item
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .font(theme.font(12, weight: .semibold))

                            let count = unreadCount(for: item)
                            if count > 0 {
                                Text("\(count)")
                                    .font(theme.font(10, weight: .bold))
                                    .foregroundColor(folder == item ? theme.accent.onAccent : theme.accent.main)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(
                                            folder == item
                                                ? AnyShapeStyle(theme.accent.main.opacity(0.25))
                                                : AnyShapeStyle(theme.accent.main.opacity(0.14))
                                        )
                                    )
                            }
                        }
                        .foregroundColor(folder == item ? theme.accent.onAccent : theme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background {
                            if folder == item {
                                Capsule().fill(.clear).accentSurface(Capsule())
                            } else {
                                Capsule().fill(theme.card)
                            }
                        }
                        .overlay(
                            Capsule()
                                .stroke(theme.separator.opacity(folder == item ? 0 : 1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ThemePressStyle())
                    .accessibilityAddTraits(folder == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    private func unreadCount(for item: ChatFolder) -> Int {
        tdlib.mainChats
            .filter { item.matches($0) && !$0.isMuted }
            .reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Список

    private var chatsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredChats) { chat in
                    NavigationLink(value: chat.id) {
                        ChatRow(chat: chat, preview: preview(for: chat))
                    }
                    .buttonStyle(ThemePressStyle())
                    .contextMenu {
                        Button {
                            tdlib.togglePin(chat)
                        } label: {
                            Label(chat.isPinned ? "Открепить" : "Закрепить", systemImage: "pin")
                        }

                        Button {
                            tdlib.toggleMute(chat)
                        } label: {
                            Label(chat.isMuted ? "Включить звук" : "Без звука", systemImage: chat.isMuted ? "bell.fill" : "bell.slash.fill")
                        }

                        Button {
                            tdlib.markAsRead(chat)
                        } label: {
                            Label("Прочитать", systemImage: "checkmark.circle")
                        }

                        Button {
                            tdlib.toggleMarkedAsUnread(chat)
                        } label: {
                            Label(chat.isMarkedAsUnread ? "Снять отметку" : "Отметить непрочитанным", systemImage: "envelope.badge")
                        }

                        Divider()

                        Button(role: .destructive) {
                            clearTarget = chat
                            showClearConfirm = true
                        } label: {
                            Label("Очистить историю", systemImage: "trash")
                        }
                    }
                }
                if folder == .all && searchText.isEmpty && tdlib.hasMoreChats {
                    if tdlib.isLoadingChats {
                        ProgressView().padding(14)
                    } else {
                        Button("Загрузить ещё чаты") { tdlib.loadChats() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .refreshable {
            tdlib.loadChats()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            ThemeEmptyState(icon: "bubble.left.and.bubble.right",
                            title: searchText.isEmpty ? "Нет чатов" : "Нет результатов",
                            detail: emptyText)

            if tdlib.mainChats.isEmpty && tdlib.hasMoreChats {
                Button {
                    tdlib.loadChats()
                } label: {
                    Text("Обновить")
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(theme.accent.onAccent)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .accentSurface(Capsule())
                }
                .buttonStyle(ThemePressStyle())
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyText: String {
        if tdlib.mainChats.isEmpty {
            return "Список чатов пуст.\nЕсли это длится долго — проверьте подключение."
        }
        if !searchText.isEmpty {
            return "По запросу «\(searchText)» ничего не найдено."
        }
        return folder == .unread ? "Все загруженные чаты прочитаны." : "В этой папке пока нет чатов."
    }

    private func preview(for chat: RealChat) -> String {
        var prefix = ""

        if chat.isGroup, let senderID = chat.lastMessageSenderID {
            if senderID == tdlib.me?.id {
                prefix = "Вы: "
            } else if let user = tdlib.users[senderID] {
                prefix = "\(user.firstName): "
            }
        }

        let body = chat.lastMessageText.isEmpty ? "Нет сообщений" : chat.lastMessageText
        return prefix + body
    }
}

struct ChatRow: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    let chat: RealChat
    let preview: String

    private var user: RealUser? {
        tdlib.user(chat.userID)
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                title: chat.title,
                fileID: chat.photoFileID ?? user?.photoFileID,
                preview: chat.photoPreview ?? user?.photoPreview,
                size: theme.chatAvatar,
                isOnline: user?.isOnline ?? false,
                highlight: chat.unreadCount > 0
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(chat.title)
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if chat.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(theme.accent.main)
                    }

                    Spacer(minLength: 4)

                    if theme.profile.showsChatTime != false {
                        Text(chat.time)
                            .font(theme.font(11, weight: chat.unreadCount > 0 ? .semibold : .regular))
                            .foregroundColor(chat.unreadCount > 0 ? theme.accent.main : theme.textSecondary)
                    }
                }

                HStack(spacing: 6) {
                    if theme.profile.showsChatPreview != false {
                        Text(preview)
                            .font(theme.font(13))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary)
                    }

                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                    }

                    if chat.isMarkedAsUnread && chat.unreadCount == 0 {
                        Circle()
                            .fill(theme.accent.main)
                            .frame(width: 8, height: 8)
                    } else if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(theme.font(10, weight: .bold))
                            .foregroundColor(chat.isMuted ? theme.textPrimary : theme.accent.onAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(chat.isMuted ? AnyShapeStyle(theme.field) : AnyShapeStyle(theme.accent.gradient)))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, CGFloat(theme.chatDensity.padding))
        .background(theme.card)
        .overlay(alignment: .bottom) {
            if theme.profile.showsChatDividers != false {
                Divider().overlay(theme.separator.opacity(0.5)).padding(.leading, theme.chatAvatar + 28)
            }
        }
    }
}

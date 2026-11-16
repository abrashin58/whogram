import SwiftUI
import TDLibKit

// MARK: - НАСТРОЙКИ TELEGRAM

private let TELEGRAM_API_ID = 94575
private let TELEGRAM_API_HASH = "a3406de8d171bb422bb6ddf3bbd800e2"

// MARK: - МОДЕЛИ

struct RealChat: Identifiable, Equatable {
    let id: Int64
    var title: String
    var lastMessage: String
    var time: String
    var unreadCount: Int
}

struct RealMessage: Identifiable, Equatable {
    let id: Int64
    let text: String
    let date: Int
    let isOutgoing: Bool

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(
            from: Date(timeIntervalSince1970: TimeInterval(date))
        )
    }
}

// MARK: - TELEGRAM AUTH / TDLib

final class TelegramAuth: ObservableObject {
    private var client: TdClient!

    @Published var statusMessage = "Запуск Whogram..."
    @Published var showCodeField = false
    @Published var showPasswordField = false
    @Published var isAuthorized = false
    @Published var isLoading = true
    @Published var chats: [RealChat] = []
    @Published var messages: [Int64: [RealMessage]] = [:]
    @Published var errorMessage: String?

    init() {
        client = TdClientImpl(completionQueue: .main)

        client.run { [weak self] data in
            DispatchQueue.main.async {
                self?.handleResponse(data)
            }
        }
    }

// MARK: Отправка запросов

private struct RawTdQuery: TdQuery {
    var object: [String: Any]

    func make(with extra: String?) throws -> Data {
        var dict = object
        if let extra = extra {
            dict["@extra"] = extra
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

private func send(_ object: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(object) else {
        errorMessage = "Ошибка формирования запроса"
        return
    }

    try? client.send(query: RawTdQuery(object: object), completion: nil)
}

    // MARK: Обработка TDLib

    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
        let type = json["@type"] as? String else {
            return
        }

        if type == "error" {
            let message = json["message"] as? String ?? "Ошибка TDLib"
            let code = json["code"] as? Int ?? 0
            if code != 400 {
                errorMessage = "\(code): \(message)"
                statusMessage = message
            }
            isLoading = false
            return
        }

        switch type {
        case "updateAuthorizationState":
            if let state = json["authorization_state"] as? [String: Any] {
                handleAuthorization(state)
            }

        case "updateNewChat":
            if let chat = json["chat"] as? [String: Any] {
                updateChat(chat)
            }

        case "updateChatLastMessage":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }),
               let message = json["last_message"] as? [String: Any] {
                chats[index].lastMessage = messageText(message)
                chats[index].time = messageTime(message)
            }

        case "updateChatUnreadCount":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].unreadCount =
                    (json["unread_count"] as? NSNumber)?.intValue ?? 0
            }

        case "updateChatReadInbox":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].unreadCount =
                    (json["unread_count"] as? NSNumber)?.intValue ?? 0
            }

        case "updateChatTitle":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let title = json["title"] as? String,
               let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].title = title
            }

        case "updateNewMessage":
            if let message = json["message"] as? [String: Any] {
                updateMessage(message)
            }

        case "messages":
            if let items = json["messages"] as? [[String: Any]],
               let firstMsg = items.first,
               let chatID = (firstMsg["chat_id"] as? NSNumber)?.int64Value {
                let parsed = items.compactMap(parseMessage)
                var current = messages[chatID] ?? []
                for msg in parsed {
                    if !current.contains(where: { $0.id == msg.id }) {
                        current.append(msg)
                    }
                }
                messages[chatID] = current.sorted { $0.id < $1.id }
            }

        default:
            break
        }
    }

    // MARK: Авторизация

    private func handleAuthorization(_ state: [String: Any]) {
        guard let type = state["@type"] as? String else {
            return
        }

        switch type {
        case "authorizationStateWaitTdlibParameters":
            statusMessage = "Настройка Telegram..."
            sendParameters()

        case "authorizationStateWaitEncryptionKey":
            statusMessage = "Подготовка базы данных..."
            send([
                "@type": "checkDatabaseEncryptionKey",
                "encryption_key": ""
            ])

        case "authorizationStateWaitPhoneNumber":
            statusMessage = "Введите номер телефона"
            isLoading = false

        case "authorizationStateWaitCode":
            statusMessage = "Введите код Telegram"
            showCodeField = true
            showPasswordField = false
            isLoading = false

        case "authorizationStateWaitPassword":
            statusMessage = "Введите облачный пароль Telegram"
            showPasswordField = true
            isLoading = false

        case "authorizationStateReady":
            isAuthorized = true
            isLoading = false
            statusMessage = "Подключено"
            loadChats()

        case "authorizationStateClosed":
            statusMessage = "Соединение закрыто"
            isLoading = false

        default:
            break
        }
    }

    private func sendParameters() {
        let base = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let database = base.appendingPathComponent("Whogram/Database")
        let files = base.appendingPathComponent("Whogram/Files")

        try? FileManager.default.createDirectory(
            at: database,
            withIntermediateDirectories: true
        )

        try? FileManager.default.createDirectory(
            at: files,
            withIntermediateDirectories: true
        )

        send([
            "@type": "setTdlibParameters",
            "api_id": TELEGRAM_API_ID,
            "api_hash": TELEGRAM_API_HASH,
            "database_directory": database.path,
            "files_directory": files.path,
            "database_encryption_key": "",
            "use_file_database": true,
            "use_chat_info_database": true,
            "use_message_database": true,
            "use_secret_chats": false,
            "use_test_dc": false,
            "system_language_code": "ru",
            "device_model": "iPhone 14 Pro",
            "system_version": "iOS 16.0",
            "application_version": "1.0",
            "enable_storage_optimizer": true,
            "ignore_file_names": false
        ])
    }

    func sendPhoneNumber(_ phone: String) {
        errorMessage = nil
        statusMessage = "Запрос авторизации..."

        send([
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phone
        ])
    }

    func sendAuthCode(_ code: String) {
        errorMessage = nil
        statusMessage = "Проверка кода..."

        send([
            "@type": "checkAuthenticationCode",
            "code": code
        ])
    }

    func sendPassword(_ password: String) {
        errorMessage = nil
        statusMessage = "Проверка пароля..."

        send([
            "@type": "checkAuthenticationPassword",
            "password": password
        ])
    }

    // MARK: Чаты

    func loadChats() {
        send([
            "@type": "loadChats",
            "chat_list": ["@type": "chatListMain"],
            "limit": 100
        ])
    }

    private func updateChat(_ chat: [String: Any]) {
        guard let id = (chat["id"] as? NSNumber)?.int64Value,
              let title = chat["title"] as? String else {
            return
        }

        let last = chat["last_message"] as? [String: Any]

        let item = RealChat(
            id: id,
            title: title,
            lastMessage: last.map { messageText($0) } ?? "Нет сообщений",
            time: last.map { messageTime($0) } ?? "",
            unreadCount: (chat["unread_count"] as? NSNumber)?.intValue ?? 0
        )

        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats[index] = item
        } else {
            chats.append(item)
        }
    }

    func openChat(_ chat: RealChat) {
        send([
            "@type": "openChat",
            "chat_id": chat.id
        ])

        loadHistory(chat.id)
    }

    func closeChat(_ chat: RealChat) {
        send([
            "@type": "closeChat",
            "chat_id": chat.id
        ])
    }

    func loadHistory(_ chatID: Int64) {
        send([
            "@type": "getChatHistory",
            "chat_id": chatID,
            "from_message_id": 0,
            "offset": 0,
            "limit": 50,
            "only_local": false
        ])
    }

    // MARK: Сообщения

    private func parseMessage(_ message: [String: Any]) -> RealMessage? {
        guard let id = (message["id"] as? NSNumber)?.int64Value else {
            return nil
        }

        return RealMessage(
            id: id,
            text: messageText(message),
            date: (message["date"] as? NSNumber)?.intValue ?? 0,
            isOutgoing: (message["is_outgoing"] as? Bool) ?? false
        )
    }

    private func updateMessage(_ message: [String: Any]) {
        guard let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let item = parseMessage(message) else {
            return
        }

        var current = messages[chatID] ?? []

        if !current.contains(where: { $0.id == item.id }) {
            current.append(item)
            current.sort { $0.id < $1.id }
        }

        messages[chatID] = current

        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].lastMessage = item.text
            chats[index].time = item.formattedTime
        }
    }

    private func messageText(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any],
              let type = content["@type"] as? String else {
            return "Сообщение"
        }

        switch type {
        case "messageText":
            let text = content["text"] as? [String: Any]
            return text?["text"] as? String ?? "Сообщение"
        case "messagePhoto":
            return "📷 Фото"
        case "messageVideo":
            return "🎬 Видео"
        case "messageVoiceNote":
            return "🎤 Голосовое сообщение"
        case "messageDocument":
            return "📎 Файл"
        case "messageSticker":
            return "🎨 Стикер"
        case "messageAnimation":
            return "GIF"
        case "messageAudio":
            return "🎵 Аудио"
        case "messageLocation":
            return "📍 Геопозиция"
        default:
            return "Сообщение"
        }
    }

    private func messageTime(_ message: [String: Any]) -> String {
        guard let date = (message["date"] as? NSNumber)?.intValue else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        return formatter.string(
            from: Date(timeIntervalSince1970: TimeInterval(date))
        )
    }

    func sendMessage(chatID: Int64, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": [
                    "@type": "formattedText",
                    "text": trimmed,
                    "entities": []
                ],
                "clear_draft": true
            ]
        ])
    }
}

// MARK: - ГЛАВНЫЙ ЭКРАН

struct ContentView: View {
    @StateObject private var auth = TelegramAuth()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if auth.isAuthorized {
                    ChatListView(auth: auth)
                } else {
                    LoginView(auth: auth)
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - АНИМАЦИЯ ЗАПУСКА (Совместимо с iOS 16)

struct SplashView: View {
    @State private var scale: CGFloat = 0.75
    @State private var glow = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "message.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.green)
                    .scaleEffect(scale)
                    .shadow(
                        color: Color.green.opacity(glow ? 0.8 : 0.15),
                        radius: glow ? 28 : 8
                    )

                Text("Whogram")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("PRIVATE MESSENGER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(4)
                    .foregroundColor(.gray)

                ProgressView()
                    .tint(.green)
                    .padding(.top, 15)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                scale = 1.0
            }

            withAnimation(
                Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
            ) {
                glow = true
            }
        }
    }
}

// MARK: - АВТОРИЗАЦИЯ

struct LoginView: View {
    @ObservedObject var auth: TelegramAuth

    @State private var phone = "+7"
    @State private var code = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 25) {
                Spacer()

                Image(systemName: "message.fill")
                    .font(.system(size: 55))
                    .foregroundColor(.green)

                Text("Whogram")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.white)

                Text(auth.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    if auth.showPasswordField {
                        inputField(
                            "Облачный пароль",
                            text: $password,
                            secure: true
                        )

                        actionButton("Подтвердить") {
                            auth.sendPassword(password)
                        }

                    } else if auth.showCodeField {
                        inputField("Код Telegram", text: $code)

                        actionButton("Войти") {
                            auth.sendAuthCode(code)
                        }

                    } else {
                        inputField("Номер телефона", text: $phone)

                        actionButton("Получить код") {
                            auth.sendPhoneNumber(phone)
                        }
                    }
                }

                if auth.isLoading {
                    ProgressView()
                        .tint(.green)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.horizontal, 25)
        }
    }

    private func inputField(
        _ title: String,
        text: Binding<String>,
        secure: Bool = false
    ) -> some View {
        Group {
            if secure {
                SecureField(title, text: text)
            } else {
                TextField(title, text: text)
                    .keyboardType(
                        title.contains("телефона") ||
                        title.contains("Код")
                        ? .numberPad : .default
                    )
            }
        }
        .foregroundColor(.white)
        .padding(17)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func actionButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(17)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - СПИСОК ЧАТОВ

struct ChatListView: View {
    @ObservedObject var auth: TelegramAuth

    @State private var searchText = ""
    @State private var selectedFolder = "Все"

    private let folders = ["Все", "Личное", "Работа", "Избранное"]

    private var filteredChats: [RealChat] {
        auth.chats.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("Сообщения")
                            .font(.system(size: 29, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            auth.loadChats()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.green)
                        }

                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.leading, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Поиск чатов", text: $searchText)
                            .foregroundColor(.white)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(folders, id: \.self) { folder in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFolder = folder
                                    }
                                } label: {
                                    Text(folder)
                                        .font(.subheadline.weight(
                                            selectedFolder == folder
                                            ? .bold : .regular
                                        ))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedFolder == folder
                                            ? Color.green.opacity(0.25)
                                            : Color.white.opacity(0.06)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 17)

                    if filteredChats.isEmpty {
                        Spacer()

                        ProgressView()
                            .tint(.green)

                        Text(searchText.isEmpty
                             ? "Загрузка настоящих чатов..."
                             : "Чаты не найдены")
                            .foregroundColor(.gray)
                            .padding(.top, 10)

                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredChats) { chat in
                                    NavigationLink {
                                        ChatDetailView(
                                            auth: auth,
                                            chat: chat
                                        )
                                    } label: {
                                        ChatCellView(chat: chat)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 110)
                        }
                        .padding(.top, 10)
                    }
                }

                VStack {
                    Spacer()

                    HStack {
                        Spacer()
                        Image(systemName: "person.crop.circle")
                        Spacer()
                        Image(systemName: "phone")
                        Spacer()

                        Image(systemName: "message.fill")
                            .foregroundColor(.black)
                            .padding(14)
                            .background(Color.green)
                            .clipShape(Circle())

                        Spacer()
                        Image(systemName: "gearshape")
                        Spacer()
                    }
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.10))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ЯЧЕЙКА ЧАТА

struct ChatCellView: View {
    let chat: RealChat

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.5), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(chat.title.prefix(1)).uppercased())
                        .font(.title3.bold())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(chat.time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text(chat.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .frame(minWidth: 21, minHeight: 21)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
        .contentShape(Rectangle())
    }
}

// MARK: - ОТКРЫТАЯ ПЕРЕПИСКА

struct ChatDetailView: View {
    @ObservedObject var auth: TelegramAuth

    let chat: RealChat

    @State private var messageText = ""

    private var chatMessages: [RealMessage] {
        auth.messages[chat.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(15)
                }
                .onChange(of: chatMessages.count) { _ in
                    if let last = chatMessages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Сообщение...", text: $messageText)
                    .foregroundColor(.white)
                    .padding(13)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Capsule())

                Button {
                    let text = messageText
                    guard !text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty else { return }

                    auth.sendMessage(chatID: chat.id, text: text)
                    messageText = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            auth.openChat(chat)
        }
        .onDisappear {
            auth.closeChat(chat)
        }
    }
}

// MARK: - ПУЗЫРЬ СООБЩЕНИЯ

struct MessageBubble: View {
    let message: RealMessage

    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 45)
            }

            VStack(alignment: .trailing, spacing: 5) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(12)
            .background(
                message.isOutgoing
                ? Color.green.opacity(0.25)
                : Color.white.opacity(0.10)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )

            if !message.isOutgoing {
                Spacer(minLength: 45)
            }
        }
    }
}
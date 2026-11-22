import SwiftUI
import TDLibKit
import PhotosUI

// MARK: - НАСТРОЙКИ TELEGRAM

private let TELEGRAM_API_ID = 2086616
private let TELEGRAM_API_HASH = "f7f60be4652cacd57a47e695da26f04d"

// MARK: - МОДЕЛИ

enum MessageContent: Equatable {
    case text(String)
    case photo(fileId: Int32, localPath: String?, caption: String)
    case video(text: String)
    case voice(text: String)
    case document(text: String)
    case unsupported(String)
}

struct RealChat: Identifiable, Equatable {
    let id: Int64
    var title: String
    var lastMessage: String
    var time: String
    var unreadCount: Int
}

struct RealMessage: Identifiable, Equatable {
    let id: Int64
    let content: MessageContent
    let date: Int
    let isOutgoing: Bool

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }
}

struct UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
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
    
    @Published var downloadedFiles: [Int32: String] = [:]
    @Published var currentUser = UserProfile()

    init() {
        client = TdClientImpl(completionQueue: .main)
        client.run { [weak self] data in
            DispatchQueue.main.async { self?.handleResponse(data) }
        }
    }

    private struct RawTdQuery: TdQuery {
        var object: [String: Any]
        func make(with extra: String?) throws -> Data {
            var dict = object
            if let extra = extra { dict["@extra"] = extra }
            return try JSONSerialization.data(withJSONObject: dict, options: [])
        }
    }

    private func send(_ object: [String: Any]) {
        try? client.send(query: RawTdQuery(object: object), completion: nil)
    }

    // MARK: Обработка TDLib
    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["@type"] as? String else { return }

        if type == "error" {
            let message = json["message"] as? String ?? "Ошибка TDLib"
            let code = json["code"] as? Int ?? 0
            errorMessage = "\(code): \(message)"
            isLoading = false
            return
        }

        switch type {
        case "updateAuthorizationState":
            if let state = json["authorization_state"] as? [String: Any] { handleAuthorization(state) }
        case "updateNewChat":
            if let chat = json["chat"] as? [String: Any] { updateChat(chat) }
        case "updateChatLastMessage":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }),
               let message = json["last_message"] as? [String: Any] {
                chats[index].lastMessage = previewText(message)
                chats[index].time = messageTime(message)
            }
        case "updateChatReadInbox", "updateChatUnreadCount":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].unreadCount = (json["unread_count"] as? NSNumber)?.intValue ?? 0
            }
        case "updateNewMessage":
            if let message = json["message"] as? [String: Any] { updateMessage(message) }
        case "messages":
            if let items = json["messages"] as? [[String: Any]],
               let firstMsg = items.first,
               let chatID = (firstMsg["chat_id"] as? NSNumber)?.int64Value {
                let parsed = items.compactMap(parseMessage)
                var current = messages[chatID] ?? []
                for msg in parsed {
                    if !current.contains(where: { $0.id == msg.id }) { current.append(msg) }
                }
                messages[chatID] = current.sorted { $0.id < $1.id }
            }
        case "updateFile":
            if let file = json["file"] as? [String: Any],
               let id = file["id"] as? Int32,
               let local = file["local"] as? [String: Any],
               let path = local["path"] as? String,
               let isCompleted = local["is_downloading_completed"] as? Bool,
               isCompleted && !path.isEmpty {
                downloadedFiles[id] = path
            }
        case "user":
            if let user = json as? [String: Any] {
                currentUser.firstName = user["first_name"] as? String ?? ""
                currentUser.lastName = user["last_name"] as? String ?? ""
                currentUser.phone = user["phone_number"] as? String ?? ""
            }
        default: break
        }
    }

    // MARK: Авторизация
    private func handleAuthorization(_ state: [String: Any]) {
        guard let type = state["@type"] as? String else { return }

        switch type {
        case "authorizationStateWaitTdlibParameters":
            statusMessage = "Настройка Telegram..."
            sendParameters()
        case "authorizationStateWaitEncryptionKey":
            statusMessage = "Подготовка базы данных..."
            send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
        case "authorizationStateWaitPhoneNumber":
            statusMessage = "Введите номер телефона"
            isLoading = false
        case "authorizationStateWaitCode":
            statusMessage = "Введите код Telegram"
            showCodeField = true; showPasswordField = false; isLoading = false
        case "authorizationStateWaitPassword":
            statusMessage = "Введите облачный пароль Telegram"
            showPasswordField = true; isLoading = false
        case "authorizationStateReady":
            isAuthorized = true; isLoading = false
            statusMessage = "Подключено"
            loadChats()
            send(["@type": "getMe"])
        case "authorizationStateClosed":
            statusMessage = "Соединение закрыто"
            isLoading = false
        default: break
        }
    }

    private func sendParameters() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let database = base.appendingPathComponent("Whogram/Database")
        let files = base.appendingPathComponent("Whogram/Files")

        try? FileManager.default.createDirectory(at: database, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)

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
            "device_model": "iPhone",
            "system_version": "iOS",
            "application_version": "1.0",
            "enable_storage_optimizer": true,
            "ignore_file_names": false
        ])
    }

    func sendPhoneNumber(_ phone: String) {
        errorMessage = nil; statusMessage = "Запрос авторизации..."
        send([
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phone,
            "settings": [
                "@type": "phoneNumberAuthenticationSettings",
                "allow_flash_call": false,
                "is_current_phone_number": false,
                "allow_sms_retriever_api": false
            ]
        ])
    }

    func sendAuthCode(_ code: String) {
        errorMessage = nil; statusMessage = "Проверка кода..."
        send(["@type": "checkAuthenticationCode", "code": code])
    }

    func sendPassword(_ password: String) {
        errorMessage = nil; statusMessage = "Проверка пароля..."
        send(["@type": "checkAuthenticationPassword", "password": password])
    }
    
    func logOut() {
        send(["@type": "logOut"])
    }

    // MARK: Чаты
    func loadChats() {
        send(["@type": "loadChats", "chat_list": ["@type": "chatListMain"], "limit": 100])
    }

    private func updateChat(_ chat: [String: Any]) {
        guard let id = (chat["id"] as? NSNumber)?.int64Value,
              let title = chat["title"] as? String else { return }
        let last = chat["last_message"] as? [String: Any]
        let item = RealChat(
            id: id, title: title,
            lastMessage: last.map { previewText($0) } ?? "Нет сообщений",
            time: last.map { messageTime($0) } ?? "",
            unreadCount: (chat["unread_count"] as? NSNumber)?.intValue ?? 0
        )
        if let index = chats.firstIndex(where: { $0.id == id }) { chats[index] = item }
        else { chats.append(item) }
    }

    func openChat(_ chat: RealChat) {
        send(["@type": "openChat", "chat_id": chat.id])
        loadHistory(chat.id)
    }

    func closeChat(_ chat: RealChat) { send(["@type": "closeChat", "chat_id": chat.id]) }

    func loadHistory(_ chatID: Int64) {
        send(["@type": "getChatHistory", "chat_id": chatID, "from_message_id": 0, "offset": 0, "limit": 50, "only_local": false])
    }

    // MARK: Сообщения
    private func parseMessage(_ message: [String: Any]) -> RealMessage? {
        guard let id = (message["id"] as? NSNumber)?.int64Value else { return nil }
        return RealMessage(
            id: id,
            content: extractContent(message),
            date: (message["date"] as? NSNumber)?.intValue ?? 0,
            isOutgoing: (message["is_outgoing"] as? Bool) ?? false
        )
    }

    private func updateMessage(_ message: [String: Any]) {
        guard let chatID = (message["chat_id"] as? NSNumber)?.int64Value,
              let item = parseMessage(message) else { return }
        var current = messages[chatID] ?? []
        if !current.contains(where: { $0.id == item.id }) {
            current.append(item)
            current.sort { $0.id < $1.id }
        }
        messages[chatID] = current
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].lastMessage = previewText(message)
            chats[index].time = item.formattedTime
        }
    }

    private func extractContent(_ message: [String: Any]) -> MessageContent {
        guard let content = message["content"] as? [String: Any],
              let type = content["@type"] as? String else { return .unsupported("Сообщение") }

        switch type {
        case "messageText":
            let text = content["text"] as? [String: Any]
            return .text(text?["text"] as? String ?? "")
        case "messagePhoto":
            if let photo = content["photo"] as? [String: Any],
               let sizes = photo["sizes"] as? [[String: Any]],
               let lastSize = sizes.last,
               let p = lastSize["photo"] as? [String: Any],
               let fileId = p["id"] as? Int32 {
                
                downloadFile(fileId: fileId)
                
                let captionObj = content["caption"] as? [String: Any]
                let caption = captionObj?["text"] as? String ?? ""
                
                return .photo(fileId: fileId, localPath: downloadedFiles[fileId], caption: caption)
            }
            return .unsupported("📷 Фото")
        case "messageVideo": return .video(text: "🎬 Видео")
        case "messageVoiceNote": return .voice(text: "🎤 Голосовое")
        case "messageVideoNote": return .voice(text: "⭕️ Видеосообщение")
        case "messageDocument": return .document(text: "📎 Файл")
        default: return .unsupported("Сообщение")
        }
    }
    
    private func previewText(_ message: [String: Any]) -> String {
        let content = extractContent(message)
        switch content {
        case .text(let t): return t
        case .photo(_, _, let caption): return caption.isEmpty ? "📷 Фото" : "📷 \(caption)"
        case .video(let t): return t
        case .voice(let t): return t
        case .document(let t): return t
        case .unsupported(let t): return t
        }
    }

    private func messageTime(_ message: [String: Any]) -> String {
        guard let date = (message["date"] as? NSNumber)?.intValue else { return "" }
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }

    func downloadFile(fileId: Int32) {
        if downloadedFiles[fileId] == nil {
            send(["@type": "downloadFile", "file_id": fileId, "priority": 1, "offset": 0, "limit": 0, "synchronous": false])
        }
    }

    func sendMessage(chatID: Int64, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send([
            "@type": "sendMessage", "chat_id": chatID,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": ["@type": "formattedText", "text": trimmed, "entities": []],
                "clear_draft": true
            ]
        ])
    }
    
    func sendPhoto(chatID: Int64, path: String) {
        send([
            "@type": "sendMessage", "chat_id": chatID,
            "input_message_content": [
                "@type": "inputMessagePhoto",
                "photo": ["@type": "inputFileLocal", "path": path],
                "added_sticker_file_ids": []
            ]
        ])
    }
}

// MARK: - ГЛАВНЫЙ ЭКРАН

struct ContentView: View {
    @StateObject private var auth = TelegramAuth()
    
    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
    }

    var body: some View {
        Group {
            if auth.isAuthorized {
                TabView {
                    ChatListView(auth: auth)
                        .tabItem {
                            Image(systemName: "message.fill")
                            Text("Чаты")
                        }
                    
                    SettingsView(auth: auth)
                        .tabItem {
                            Image(systemName: "gearshape.fill")
                            Text("Настройки")
                        }
                }
                .tint(.green)
            } else {
                LoginView(auth: auth)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - НАСТРОЙКИ
struct SettingsView: View {
    @ObservedObject var auth: TelegramAuth
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(auth.currentUser.firstName.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(auth.currentUser.firstName) \(auth.currentUser.lastName)")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("+\(auth.currentUser.phone)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(role: .destructive) {
                        auth.logOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
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
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 55))
                    .foregroundColor(.green)
                Text("Whogram")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.white)
                Text(auth.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let error = auth.errorMessage {
                    Text(error).font(.callout.bold()).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal)
                }

                VStack(spacing: 16) {
                    if auth.showPasswordField {
                        inputField("Облачный пароль", text: $password, secure: true)
                        actionButton("Подтвердить") { auth.sendPassword(password) }
                    } else if auth.showCodeField {
                        inputField("Код Telegram", text: $code)
                        actionButton("Войти") { auth.sendAuthCode(code) }
                    } else {
                        inputField("Номер телефона", text: $phone)
                        actionButton("Получить код") { auth.sendPhoneNumber(phone) }
                    }
                }
                if auth.isLoading { ProgressView().tint(.green) }
                Spacer()
            }
            .padding(.horizontal, 25)
        }
    }

    private func inputField(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        Group {
            if secure { SecureField(title, text: text).textContentType(.password) }
            else {
                TextField(title, text: text)
                    .keyboardType(title.contains("телефона") ? .phonePad : title.contains("Код") ? .numberPad : .default)
                    .textContentType(title.contains("телефона") ? .telephoneNumber : title.contains("Код") ? .oneTimeCode : .none)
            }
        }
        .foregroundColor(.white).padding(17).background(Color.white.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding(17).background(Color.green).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - СПИСОК ЧАТОВ

struct ChatListView: View {
    @ObservedObject var auth: TelegramAuth
    @State private var searchText = ""

    private var filteredChats: [RealChat] {
        auth.chats.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredChats) { chat in
                NavigationLink(destination: ChatDetailView(auth: auth, chat: chat)) {
                    ChatCellView(chat: chat)
                }
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Сообщения")
            .searchable(text: $searchText, prompt: "Поиск чатов")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { auth.loadChats() }) {
                        Image(systemName: "arrow.clockwise").foregroundColor(.green)
                    }
                }
            }
        }
    }
}

struct ChatCellView: View {
    let chat: RealChat
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color.gray.opacity(0.5), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(Text(String(chat.title.prefix(1)).uppercased()).font(.title3.bold()).foregroundColor(.white))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text(chat.time).font(.caption).foregroundColor(.gray)
                }
                HStack {
                    Text(chat.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)").font(.caption2.bold()).foregroundColor(.black).padding(.horizontal, 6).padding(.vertical, 2).background(Color.green).clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ОТКРЫТАЯ ПЕРЕПИСКА

struct ChatDetailView: View {
    @ObservedObject var auth: TelegramAuth
    let chat: RealChat
    @State private var messageText = ""
    @State private var selectedItem: PhotosPickerItem? = nil

    private var chatMessages: [RealMessage] { auth.messages[chat.id] ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            MessageBubble(message: message, downloadedFiles: auth.downloadedFiles)
                                .id(message.id)
                                .rotationEffect(.degrees(180)) // Хитрость для правильного скролла
                        }
                    }
                    .padding(15)
                }
                .rotationEffect(.degrees(180)) // Хитрость для правильного скролла
            }

            // ПАНЕЛЬ ВВОДА
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "paperclip")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            sendImage(image)
                        }
                    }
                }

                TextField("Сообщение...", text: $messageText)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())

                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {}) {
                        Image(systemName: "mic")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                } else {
                    Button {
                        let text = messageText
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        auth.sendMessage(chatID: chat.id, text: text)
                        messageText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(white: 0.05))
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { auth.openChat(chat) }
        .onDisappear { auth.closeChat(chat) }
    }
    
    private func sendImage(_ image: UIImage) {
        // Сохраняем фото во временную папку для отправки
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try? data.write(to: tempURL)
        auth.sendPhoto(chatID: chat.id, path: tempURL.path)
    }
}

// MARK: - ПУЗЫРЬ СООБЩЕНИЯ

struct MessageBubble: View {
    let message: RealMessage
    let downloadedFiles: [Int32: String]

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: .trailing, spacing: 5) {
                // КОНТЕНТ СООБЩЕНИЯ
                switch message.content {
                case .text(let text):
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                case .photo(let fileId, let localPath, let caption):
                    // Отображение фото
                    if let path = localPath ?? downloadedFiles[fileId],
                       let uiImage = UIImage(contentsOfFile: path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .frame(maxWidth: 250)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(ProgressView().tint(.white))
                            .cornerRadius(10)
                    }
                    if !caption.isEmpty {
                        Text(caption).font(.system(size: 16)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                case .voice(let text):
                    HStack {
                        Image(systemName: "play.circle.fill").font(.title).foregroundColor(message.isOutgoing ? .white : .green)
                        Image(systemName: "waveform").foregroundColor(.gray)
                        Text(text).font(.caption).foregroundColor(.gray)
                    }
                    
                case .video(let text):
                    HStack {
                        Image(systemName: "video.fill").foregroundColor(.gray)
                        Text(text).foregroundColor(.white)
                    }
                    
                case .document(let text):
                    HStack {
                        Image(systemName: "doc.fill").foregroundColor(.gray)
                        Text(text).foregroundColor(.white).underline()
                    }
                    
                case .unsupported(let text):
                    Text(text).font(.system(size: 16, weight: .light, design: .monospaced)).foregroundColor(.gray)
                }

                // ВРЕМЯ
                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(12)
            .background(message.isOutgoing ? Color.green.opacity(0.3) : Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }
}
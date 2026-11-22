import Foundation
import TDLibKit

final class TDLibManager: ObservableObject {
    static let shared = TDLibManager()
    private var client: TdClient!

    @Published var authorizationState: String = "wait_tdlib_parameters"
    @Published var isAuthorized = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var statusMessage = "Инициализация..."

    @Published var chats: [RealChat] = []
    @Published var messages: [Int64: [RealMessage]] = [:]

    private init() {
        client = TdClientImpl(completionQueue: .main)
        client.run { [weak self] data in
            DispatchQueue.main.async {
                self?.handleUpdate(data)
            }
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

    func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object) else {
            errorMessage = "Ошибка формирования запроса"
            return
        }
        try? client.send(query: RawTdQuery(object: object), completion: nil)
    }

    private func handleUpdate(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["@type"] as? String else { return }

        if type == "error" {
            let message = json["message"] as? String ?? "Ошибка TDLib"
            let code = json["code"] as? Int ?? 0
            self.errorMessage = "\(code): \(message)"
            self.statusMessage = "Сбой"
            self.isLoading = false
            return
        }

        switch type {
        case "updateAuthorizationState":
            if let state = json["authorization_state"] as? [String: Any] {
                handleAuthState(state)
            }
        case "updateNewChat":
            if let chat = json["chat"] as? [String: Any] {
                updateChat(chat)
            }
        case "updateChatLastMessage":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }),
               let msg = json["last_message"] as? [String: Any] {
                chats[index].lastMessage = parseMessageText(msg)
                chats[index].time = parseMessageTime(msg)
            }
        case "updateChatUnreadCount", "updateChatReadInbox":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].unreadCount = (json["unread_count"] as? NSNumber)?.intValue ?? 0
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
                messages[chatID] = current.sorted { $0.id > $1.id }
            }
        default:
            break
        }
    }

    private func handleAuthState(_ state: [String: Any]) {
        guard let type = state["@type"] as? String else { return }
        self.authorizationState = type
        self.errorMessage = nil

        switch type {
        case "authorizationStateWaitTdlibParameters":
            statusMessage = "Настройка TDLib..."
            setParameters()
        case "authorizationStateWaitEncryptionKey":
            statusMessage = "Подготовка БД..."
            send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
        case "authorizationStateWaitPhoneNumber":
            statusMessage = "Введите номер телефона"
            isLoading = false
        case "authorizationStateWaitCode":
            statusMessage = "Введите код из Telegram"
            isLoading = false
        case "authorizationStateWaitPassword":
            statusMessage = "Введите облачный пароль"
            isLoading = false
        case "authorizationStateReady":
            isAuthorized = true
            isLoading = false
            statusMessage = "Подключено"
            loadChats()
        case "authorizationStateClosed":
            isAuthorized = false
            isLoading = false
            statusMessage = "Соединение закрыто"
        default:
            break
        }
    }

    private func setParameters() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = base.appendingPathComponent("Whogram/Database").path
        let filesPath = base.appendingPathComponent("Whogram/Files").path

        try? FileManager.default.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: filesPath, withIntermediateDirectories: true)

        send([
            "@type": "setTdlibParameters",
            "api_id": Constants.apiId,
            "api_hash": Constants.apiHash,
            "database_directory": dbPath,
            "files_directory": filesPath,
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

    func loadChats() {
        send(["@type": "loadChats", "chat_list": ["@type": "chatListMain"], "limit": 100])
    }

    func openChat(_ chatID: Int64) {
        send(["@type": "openChat", "chat_id": chatID])
        send([
            "@type": "getChatHistory",
            "chat_id": chatID,
            "from_message_id": 0,
            "offset": 0,
            "limit": 50,
            "only_local": false
        ])
    }

    func closeChat(_ chatID: Int64) {
        send(["@type": "closeChat", "chat_id": chatID])
    }

    func sendMessage(chatID: Int64, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": ["@type": "formattedText", "text": trimmed, "entities": []],
                "clear_draft": true
            ]
        ])
    }

    private func updateChat(_ chat: [String: Any]) {
        guard let id = (chat["id"] as? NSNumber)?.int64Value,
              let title = chat["title"] as? String else { return }

        let last = chat["last_message"] as? [String: Any]
        let item = RealChat(
            id: id,
            title: title,
            lastMessage: last.map { parseMessageText($0) } ?? "Нет сообщений",
            time: last.map { parseMessageTime($0) } ?? "",
            unreadCount: (chat["unread_count"] as? NSNumber)?.intValue ?? 0
        )

        if let idx = chats.firstIndex(where: { $0.id == id }) {
            chats[idx] = item
        } else {
            chats.append(item)
        }
    }

    private func parseMessage(_ message: [String: Any]) -> RealMessage? {
        guard let id = (message["id"] as? NSNumber)?.int64Value else { return nil }
        return RealMessage(
            id: id,
            text: parseMessageText(message),
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
            current.sort { $0.id > $1.id }
        }
        messages[chatID] = current

        if let idx = chats.firstIndex(where: { $0.id == chatID }) {
            chats[idx].lastMessage = item.text
            chats[idx].time = item.formattedTime
        }
    }

    private func parseMessageText(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any],
              let type = content["@type"] as? String else { return "Сообщение" }
        switch type {
        case "messageText":
            let text = content["text"] as? [String: Any]
            return text?["text"] as? String ?? "Сообщение"
        case "messagePhoto": return "📷 Фото"
        case "messageVideo": return "🎬 Видео"
        case "messageVideoNote": return "⚪ Видеокружок"
        case "messageVoiceNote": return "🎤 Голосовое сообщение"
        case "messageDocument": return "📎 Файл"
        case "messageSticker": return "🎨 Стикер"
        case "messageAnimation": return "GIF"
        default: return "Сообщение"
        }
    }

    private func parseMessageTime(_ message: [String: Any]) -> String {
        guard let date = (message["date"] as? NSNumber)?.intValue else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }
}

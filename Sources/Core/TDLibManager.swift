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
    
    // Данные
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
            errorMessage = "Ошибка сериализации запроса"
            return
        }
        try? client.send(query: RawTdQuery(object: object), completion: nil)
    }
    
    private func handleUpdate(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["@type"] as? String else { return }
        
        if type == "error" {
            let message = json["message"] as? String ?? "Неизвестная ошибка"
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
            if let chat = json["chat"] as? [String: Any] { updateChat(chat) }
        case "updateChatLastMessage":
            if let id = (json["chat_id"] as? NSNumber)?.int64Value,
               let index = chats.firstIndex(where: { $0.id == id }),
               let msg = json["last_message"] as? [String: Any] {
                chats[index].lastMessage = parseMessageText(msg)
                chats[index].time = parseMessageTime(msg)
            }
        // Здесь в будущем добавим обработку сообщений (Этап 3)
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
            statusMessage = "Ожидание номера телефона"
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
        send([
            "@type": "loadChats",
            "chat_list": ["@type": "chatListMain"],
            "limit": 50
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
    
    private func parseMessageText(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any],
              let type = content["@type"] as? String else { return "Сообщение" }
        switch type {
        case "messageText":
            let text = content["text"] as? [String: Any]
            return text?["text"] as? String ?? "Сообщение"
        case "messagePhoto": return "📷 Фото"
        case "messageVideo": return "🎬 Видео"
        case "messageVoiceNote": return "🎤 Голосовое сообщение"
        default: return "Медиа"
        }
    }
    
    private func parseMessageTime(_ message: [String: Any]) -> String {
        guard let date = (message["date"] as? NSNumber)?.intValue else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }
}

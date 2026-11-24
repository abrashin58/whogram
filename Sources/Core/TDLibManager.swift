import Combine
import Foundation
import TDLibKit

final class TDLibManager: ObservableObject {
    static let shared = TDLibManager()

    private var client: TdClient!

    // Авторизация
    @Published var authorizationState = "authorizationStateWaitTdlibParameters"
    @Published var isAuthorized = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var statusMessage = "Инициализация…"
    @Published var authCodePhone: String?
    @Published var authCodeLength: Int = 0
    @Published var passwordHint: String?

    // Данные
    @Published var chats: [RealChat] = []
    @Published var messages: [Int64: [RealMessage]] = [:]
    @Published var users: [Int64: RealUser] = [:]
    @Published var me: RealUser?
    @Published var myBio = ""

    // Файлы и стикеры
    @Published var filePaths: [Int32: String] = [:]
    @Published var downloading: Set<Int32> = []
    @Published var recentStickers: [RealSticker] = []
    @Published var stickerSets: [RealSticker] = []

    // Живые состояния
    @Published var typing: [Int64: String] = [:]
    @Published var searchChatIDs: [Int64] = []
    @Published var messageSearchResults: [RealMessage] = []

    private var typingTimers: [Int64: DispatchWorkItem] = [:]
    private var lastTypingSent: [Int64: Date] = [:]
    private var loadingMore: Set<Int64> = []
    private var requestedMyFullInfo = false
    private var waitingForMe = false
    private var waitingForMyFullInfo = false

    private init() {
        client = TdClientImpl(completionQueue: .main)
        client.run { [weak self] data in
            DispatchQueue.main.async {
                self?.handleUpdate(data)
            }
        }
    }

    // MARK: - Отправка запросов

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

    // MARK: - Разбор обновлений

    private func handleUpdate(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["@type"] as? String else { return }

        if type == "error" {
            handleError(json)
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
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            if let last = json["last_message"] as? [String: Any] {
                chats[index].lastMessageText = previewText(last)
                chats[index].lastMessageDate = int(last["date"]) ?? 0
                chats[index].lastMessageID = int64(last["id"]) ?? 0
                chats[index].lastMessageSenderID = senderUserID(last["sender_id"])
            } else {
                chats[index].lastMessageText = ""
                chats[index].lastMessageID = 0
                chats[index].lastMessageSenderID = nil
            }
            sortChats()

        case "updateChatPosition":
            guard let id = int64(json["chat_id"]),
                  let position = json["position"] as? [String: Any] else { return }
            let list = position["list"] as? [String: Any]
            guard (list?["@type"] as? String) == "chatListMain" else { return }
            let order = int64(position["order"]) ?? 0
            if order == 0 {
                chats.removeAll { $0.id == id }
                return
            }
            if let index = chats.firstIndex(where: { $0.id == id }) {
                chats[index].isPinned = bool(position["is_pinned"]) ?? false
                sortChats()
            }

        case "updateChatTitle":
            guard let id = int64(json["chat_id"]),
                  let title = json["title"] as? String,
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].title = title

        case "updateChatPhoto":
            guard let id = int64(json["chat_id"]),
                  let photo = json["photo"] as? [String: Any],
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].photoFileID = fileID(photo["small"]) ?? fileID(photo["big"])
            chats[index].photoPreview = mini(photo["minithumbnail"])

        case "updateChatReadInbox":
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].unreadCount = int(json["unread_count"]) ?? 0
            chats[index].lastReadInboxMessageID = int64(json["last_read_inbox_message_id"]) ?? 0

        case "updateChatReadOutbox":
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].lastReadOutboxMessageID = int64(json["last_read_outbox_message_id"]) ?? 0

        case "updateChatUnreadMentionCount":
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].unreadMentionCount = int(json["unread_mention_count"]) ?? 0

        case "updateChatIsMarkedAsUnread":
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].isMarkedAsUnread = bool(json["is_marked_as_unread"]) ?? false

        case "updateChatNotificationSettings":
            guard let id = int64(json["chat_id"]),
                  let settings = json["notification_settings"] as? [String: Any],
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].isMuted = isMuted(settings)

        case "updateChatOnlineMemberCount":
            guard let id = int64(json["chat_id"]),
                  let index = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[index].onlineCount = int(json["online_member_count"]) ?? 0

        case "updateUser":
            if let userJson = json["user"] as? [String: Any], let user = parseUser(userJson) {
                applyUser(user)
            }

        case "updateUserStatus":
            guard let id = int64(json["user_id"]),
                  let status = json["status"] as? [String: Any] else { return }
            var user = users[id] ?? RealUser(id: id)
            applyStatus(status, to: &user)
            applyUser(user)

        case "updateNewMessage":
            if let messageJson = json["message"] as? [String: Any],
               let message = parseMessage(messageJson) {
                upsertMessage(message)
                updatePreview(with: message)
            }

        case "updateMessageSendSucceeded":
            if let messageJson = json["message"] as? [String: Any],
               let message = parseMessage(messageJson) {
                let oldID = int64(json["old_message_id"]) ?? message.id
                removeMessage(id: oldID, chatID: message.chatID)
                upsertMessage(message)
                updatePreview(with: message)
            }

        case "updateMessageSendFailed":
            guard let id = int64(json["old_message_id"]),
                  let chatID = int64((json["message"] as? [String: Any])?["chat_id"]) else { return }
            markMessageFailed(id: id, chatID: chatID)

        case "updateMessageContent":
            guard let chatID = int64(json["chat_id"]),
                  let messageID = int64(json["message_id"]),
                  let content = json["new_content"] as? [String: Any] else { return }
            updateMessageContent(chatID: chatID, messageID: messageID, content: content)

        case "updateMessageEdited":
            guard let chatID = int64(json["chat_id"]),
                  let messageID = int64(json["message_id"]) else { return }
            editMessageDate(chatID: chatID, messageID: messageID, date: int(json["edit_date"]) ?? 0)

        case "updateMessageInteractionInfo":
            guard let chatID = int64(json["chat_id"]),
                  let messageID = int64(json["message_id"]),
                  let info = json["interaction_info"] as? [String: Any] else { return }
            applyInteraction(info, chatID: chatID, messageID: messageID)

        case "updateMessageReactions":
            guard let chatID = int64(json["chat_id"]),
                  let messageID = int64(json["message_id"]),
                  let list = json["reactions"] as? [[String: Any]] else { return }
            applyReactions(list, chatID: chatID, messageID: messageID)

        case "updateDeleteMessages":
            guard let chatID = int64(json["chat_id"]),
                  let ids = json["message_ids"] as? [NSNumber] else { return }
            let removed = Set(ids.map { $0.int64Value })
            messages[chatID] = (messages[chatID] ?? []).filter { !removed.contains($0.id) }

        case "updateChatAction":
            handleChatAction(json)

        case "updateFile":
            handleFile(json)

        case "messages":
            handleHistory(json)

        case "message":
            if let messageJson = json["message"] as? [String: Any],
               let message = parseMessage(messageJson) {
                upsertMessage(message)
                updatePreview(with: message)
            }

        case "foundChatMessages":
            handleFoundMessages(json)

        case "chats":
            handleChatSearch(json)

        case "chat":
            if let chat = json["chat"] as? [String: Any] {
                updateChat(chat)
            }

        case "stickers":
            if let list = json["stickers"] as? [[String: Any]] {
                recentStickers = list.compactMap(parseSticker)
                stickerSets = recentStickers
            }

        case "stickerSets":
            if let sets = json["sticker_sets"] as? [[String: Any]] {
                var result: [RealSticker] = []
                for set in sets {
                    if let list = set["sticker_list"] as? [[String: Any]] {
                        result.append(contentsOf: list.compactMap(parseSticker))
                    }
                }
                stickerSets = result
            }

        case "user":
            if let user = parseUser(json) {
                applyUser(user)
                if waitingForMe {
                    me = user
                    waitingForMe = false
                }
            }

        case "userFullInfo":
            if waitingForMyFullInfo {
                let bio = text(json["bio"])
                if !bio.isEmpty {
                    myBio = bio
                }
                waitingForMyFullInfo = false
            }

        case "supergroup":
            if let id = int64(json["id"]) {
                updateMemberCount(supergroupID: id, count: int(json["member_count"]) ?? 0)
            }

        case "basicGroup":
            if let id = int64(json["id"]) {
                updateMemberCount(basicGroupID: id, count: int(json["member_count"]) ?? 0)
            }

        case "updateSupergroup":
            if let group = json["supergroup"] as? [String: Any], let id = int64(group["id"]) {
                updateMemberCount(supergroupID: id, count: int(group["member_count"]) ?? 0)
            }

        case "updateBasicGroup":
            if let group = json["basicGroup"] as? [String: Any], let id = int64(group["id"]) {
                updateMemberCount(basicGroupID: id, count: int(group["member_count"]) ?? 0)
            }

        default:
            break
        }
    }

    private func handleError(_ json: [String: Any]) {
        let message = json["message"] as? String ?? "Ошибка TDLib"
        let code = int(json["code"]) ?? 0

        // 404 — нормальный ответ loadChats, когда все чаты уже загружены.
        if code == 404 || message == "Not Found" { return }

        errorMessage = "\(code): \(message)"
        if isLoading && !isAuthorized {
            isLoading = false
        }
    }

    // MARK: - Авторизация

    private func handleAuthState(_ state: [String: Any]) {
        guard let type = state["@type"] as? String else { return }
        authorizationState = type
        errorMessage = nil

        switch type {
        case "authorizationStateWaitTdlibParameters":
            statusMessage = "Настройка TDLib…"
            setParameters()

        case "authorizationStateWaitPhoneNumber":
            resetSession()
            statusMessage = "Введите номер телефона"
            isLoading = false

        case "authorizationStateWaitCode":
            let info = state["code_info"] as? [String: Any]
            authCodePhone = info?["phone_number"] as? String
            authCodeLength = int((info?["type"] as? [String: Any])?["length"]) ?? 0
            statusMessage = "Введите код из Telegram"
            isLoading = false

        case "authorizationStateWaitPassword":
            passwordHint = state["password_hint"] as? String
            statusMessage = "Введите облачный пароль"
            isLoading = false

        case "authorizationStateReady":
            isAuthorized = true
            isLoading = false
            errorMessage = nil
            statusMessage = "Подключено"
            loadChats()
            loadMe()
            loadRecentStickers()

        case "authorizationStateClosed":
            resetSession()
            statusMessage = "Соединение закрыто"
            isLoading = false

        default:
            break
        }
    }

    private func resetSession() {
        isAuthorized = false
        chats = []
        messages = [:]
        typing = [:]
        messageSearchResults = []
        searchChatIDs = []
        authCodePhone = nil
        passwordHint = nil
        me = nil
        myBio = ""
        requestedMyFullInfo = false
        waitingForMe = false
        waitingForMyFullInfo = false
        loadingMore = []
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
            "application_version": "1.0"
        ])
    }

    func logOut() {
        statusMessage = "Выход из аккаунта…"
        send(["@type": "logOut"])
    }

    func resendCode() {
        send([
            "@type": "resendAuthenticationCode",
            "reason": ["@type": "resendCodeReasonUserRequest"]
        ])
    }

    // MARK: - Загрузка данных

    func loadChats() {
        send([
            "@type": "loadChats",
            "chat_list": ["@type": "chatListMain"],
            "limit": 100
        ])
    }

    func loadMe() {
        waitingForMe = true
        waitingForMyFullInfo = true
        send(["@type": "getMe"])
    }

    func loadRecentStickers() {
        send(["@type": "getRecentStickers", "is_attached": false])
    }

    func searchStickers(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stickerSets = []
            return
        }
        send(["@type": "searchStickers", "emoji_prefix": trimmed.lowercased()])
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

    func loadMoreMessages(chatID: Int64) {
        guard !loadingMore.contains(chatID) else { return }
        guard let first = messages[chatID]?.first, first.id > 0 else { return }

        loadingMore.insert(chatID)
        send([
            "@type": "getChatHistory",
            "chat_id": chatID,
            "from_message_id": first.id,
            "offset": 0,
            "limit": 50,
            "only_local": false
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.loadingMore.remove(chatID)
        }
    }

    func markAsRead(_ chat: RealChat) {
        var lastID = chat.lastMessageID
        if let loaded = messages[chat.id]?.last?.id, loaded > lastID {
            lastID = loaded
        }
        guard lastID > chat.lastReadInboxMessageID else { return }

        send([
            "@type": "viewMessages",
            "chat_id": chat.id,
            "message_ids": [lastID],
            "source": ["@type": "messageSourceChatHistory"],
            "force_read": true
        ])
    }

    private func formattedText(_ text: String) -> [String: Any] {
        ["@type": "formattedText", "text": text, "entities": []]
    }

    private func replyToObject(_ replyTo: Int64?) -> Any {
        if let replyTo {
            return [
                "@type": "inputMessageReplyToMessage",
                "message_id": replyTo,
                "quote": NSNull(),
                "checklist_task_id": 0,
                "poll_option_id": ""
            ]
        }
        return NSNull()
    }

    func sendMessage(chatID: Int64, text: String, replyTo: Int64? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "reply_to": replyToObject(replyTo),
            "options": NSNull(),
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessageText",
                "text": formattedText(trimmed),
                "link_preview_options": NSNull(),
                "clear_draft": true
            ]
        ])
    }

    func editMessage(chatID: Int64, messageID: Int64, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        send([
            "@type": "editMessageText",
            "chat_id": chatID,
            "message_id": messageID,
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessageText",
                "text": formattedText(trimmed),
                "link_preview_options": NSNull(),
                "clear_draft": true
            ]
        ])
    }

    func deleteMessage(chatID: Int64, messageID: Int64) {
        send([
            "@type": "deleteMessages",
            "chat_id": chatID,
            "message_ids": [messageID],
            "revoke": true
        ])
    }

    func forwardMessage(chatID: Int64, messageID: Int64, to targetChatID: Int64) {
        send([
            "@type": "forwardMessages",
            "chat_id": targetChatID,
            "topic_id": NSNull(),
            "from_chat_id": chatID,
            "message_ids": [messageID],
            "options": [
                "@type": "messageSendOptions",
                "suggested_post_info": NSNull(),
                "disable_notification": false,
                "from_background": false,
                "protect_content": false,
                "allow_paid_broadcast": false,
                "paid_message_star_count": 0,
                "update_order_of_installed_sticker_sets": false,
                "scheduling_state": NSNull(),
                "effect_id": 0,
                "sending_id": 0,
                "only_preview": false
            ],
            "send_copy": false,
            "remove_caption": false
        ])
    }

    func sendSticker(_ sticker: RealSticker, chatID: Int64, replyTo: Int64? = nil) {
        if sticker.fileID == 0 && sticker.remoteID.isEmpty {
            sendMessage(chatID: chatID, text: sticker.emoji, replyTo: replyTo)
            return
        }

        let inputFile: [String: Any]
        if !sticker.remoteID.isEmpty {
            inputFile = ["@type": "inputFileRemote", "id": sticker.remoteID]
        } else {
            inputFile = ["@type": "inputFileId", "id": sticker.fileID]
        }

        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "reply_to": replyToObject(replyTo),
            "options": NSNull(),
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessageSticker",
                "sticker": [
                    "@type": "inputSticker",
                    "sticker": inputFile,
                    "thumbnail": NSNull(),
                    "width": max(sticker.width, 1),
                    "height": max(sticker.height, 1)
                ],
                "emoji": sticker.emoji
            ]
        ])
    }

    func sendVoiceNote(chatID: Int64, draft: VoiceNoteDraft, replyTo: Int64? = nil) {
        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "reply_to": replyToObject(replyTo),
            "options": NSNull(),
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessageVoiceNote",
                "voice_note": [
                    "@type": "inputVoiceNote",
                    "voice": ["@type": "inputFileLocal", "path": draft.url.path],
                    "duration": max(draft.duration, 0),
                    "waveform": Self.waveformBase64(for: draft.duration),
                    "mime_type": "audio/wav"
                ],
                "caption": formattedText(""),
                "disable_notification": false,
                "self_destruct_type": NSNull()
            ]
        ])
    }

    /// Синтетическая волна (Telegram использует её для визуализации голосового).
    private static func waveformBase64(for duration: Int) -> String {
        let bars = 50
        let flat = Int(max(0, min(duration, 8)) * 12) // длиннее секунды — максимальный уровень
        let values = (0..<bars).map { index -> Int in
            let t = Double(index) / Double(max(bars - 1, 1))
            let edge = 1.0 - pow(t - 0.5, 2) * 3.0 // горб по середине
            let amplitude = edge * edge
            let level = Int((amplitude * 0.75 + 0.15) * 31) + flat
            return min(max(level, 0), 31)
        }
        return Data(values.map { UInt8($0 & 0x1F) }).base64EncodedString()
    }

    func sendPhoto(chatID: Int64, path: String, width: Int, height: Int, caption: String = "", replyTo: Int64? = nil) {
        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "reply_to": replyToObject(replyTo),
            "options": NSNull(),
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessagePhoto",
                "photo": [
                    "@type": "inputPhoto",
                    "photo": ["@type": "inputFileLocal", "path": path],
                    "thumbnail": NSNull(),
                    "video": NSNull(),
                    "added_sticker_file_ids": [],
                    "width": max(width, 1),
                    "height": max(height, 1)
                ],
                "caption": formattedText(caption),
                "show_caption_above_media": false,
                "self_destruct_type": NSNull(),
                "has_spoiler": false
            ]
        ])
    }

    func sendDocument(chatID: Int64, path: String, caption: String = "", replyTo: Int64? = nil) {
        send([
            "@type": "sendMessage",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "reply_to": replyToObject(replyTo),
            "options": NSNull(),
            "reply_markup": NSNull(),
            "input_message_content": [
                "@type": "inputMessageDocument",
                "document": [
                    "@type": "inputDocument",
                    "document": ["@type": "inputFileLocal", "path": path],
                    "thumbnail": NSNull(),
                    "disable_content_type_detection": false
                ],
                "caption": formattedText(caption)
            ]
        ])
    }

    func toggleReaction(chatID: Int64, messageID: Int64, emoji: String) {
        let message = messages[chatID]?.first(where: { $0.id == messageID })
        let chosen = message?.reactions.first(where: { $0.emoji == emoji })?.isChosen ?? false
        let reaction: [String: Any] = ["@type": "reactionTypeEmoji", "emoji": emoji]

        if chosen {
            send([
                "@type": "removeMessageReaction",
                "chat_id": chatID,
                "message_id": messageID,
                "reaction_type": reaction
            ])
        } else {
            send([
                "@type": "addMessageReaction",
                "chat_id": chatID,
                "message_id": messageID,
                "reaction_type": reaction,
                "is_big": false,
                "update_recent_reactions": true
            ])
        }
    }

    func sendTyping(chatID: Int64) {
        let now = Date()
        if let last = lastTypingSent[chatID], now.timeIntervalSince(last) < 3 { return }
        lastTypingSent[chatID] = now
        send([
            "@type": "sendChatAction",
            "chat_id": chatID,
            "action": ["@type": "chatActionTyping"]
        ])
    }

    // MARK: - Действия с чатом

    func togglePin(_ chat: RealChat) {
        send([
            "@type": "toggleChatIsPinned",
            "chat_list": ["@type": "chatListMain"],
            "chat_id": chat.id,
            "is_pinned": !chat.isPinned
        ])
    }

    func toggleMute(_ chat: RealChat) {
        let muted = !chat.isMuted
        send([
            "@type": "setChatNotificationSettings",
            "chat_id": chat.id,
            "notification_settings": [
                "@type": "chatNotificationSettings",
                "use_default_mute_for": false,
                "mute_for": muted ? 2147483647 : 0,
                "use_default_sound": true,
                "sound_id": 0,
                "use_default_show_preview": true,
                "show_preview": true,
                "use_default_mute_stories": true,
                "mute_stories": false,
                "use_default_story_sound": true,
                "story_sound_id": 0,
                "use_default_show_story_poster": true,
                "show_story_poster": true,
                "use_default_disable_pinned_message_notifications": true,
                "disable_pinned_message_notifications": false,
                "use_default_disable_mention_notifications": true,
                "disable_mention_notifications": false
            ]
        ])
    }

    func toggleMarkedAsUnread(_ chat: RealChat) {
        send([
            "@type": "toggleChatIsMarkedAsUnread",
            "chat_id": chat.id,
            "is_marked_as_unread": !chat.isMarkedAsUnread
        ])
    }

    func clearHistory(_ chat: RealChat) {
        send([
            "@type": "deleteChatHistory",
            "chat_id": chat.id,
            "remove_from_chat_list": false,
            "revoke": false
        ])
        messages[chat.id] = []
    }

    func requestChatInfo(_ chat: RealChat) {
        if let id = chat.supergroupID {
            send(["@type": "getSupergroup", "supergroup_id": id])
        } else if let id = chat.basicGroupID {
            send(["@type": "getBasicGroup", "basic_group_id": id])
        } else if let userID = chat.userID {
            send(["@type": "getUser", "user_id": userID])
            send(["@type": "getUserFullInfo", "user_id": userID])
        }
    }

    func saveProfile(firstName: String, lastName: String, username: String, bio: String) {
        let currentFirst = me?.firstName ?? ""
        let currentLast = me?.lastName ?? ""
        let currentUsername = me?.username ?? ""

        if firstName != currentFirst || lastName != currentLast {
            send(["@type": "setName", "first_name": firstName, "last_name": lastName])
        }
        if username != currentUsername {
            send(["@type": "setUsername", "username": username])
        }
        if bio != myBio {
            send(["@type": "setBio", "bio": bio])
        }
    }

    // MARK: - Поиск

    func searchChats(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchChatIDs = []
            return
        }
        send([
            "@type": "searchChats",
            "query": trimmed,
            "limit": 30
        ])
    }

    func searchMessages(chatID: Int64, query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            messageSearchResults = []
            return
        }
        send([
            "@type": "searchChatMessages",
            "chat_id": chatID,
            "topic_id": NSNull(),
            "query": trimmed,
            "sender_id": NSNull(),
            "from_message_id": 0,
            "offset": 0,
            "limit": 30,
            "filter": ["@type": "searchMessagesFilterEmpty"]
        ])
    }

    func clearMessageSearch() {
        messageSearchResults = []
    }

    // MARK: - Файлы

    func downloadFile(_ fileID: Int32, priority: Int32 = 8) {
        guard fileID != 0 else { return }
        if filePaths[fileID] != nil { return }
        if downloading.contains(fileID) { return }

        downloading.insert(fileID)
        send([
            "@type": "downloadFile",
            "file_id": fileID,
            "priority": priority,
            "offset": 0,
            "limit": 0,
            "synchronous": false
        ])
    }

    func filePath(_ fileID: Int32?) -> String? {
        guard let fileID else { return nil }
        return filePaths[fileID]
    }

    // MARK: - Пользователи

    func user(_ id: Int64?) -> RealUser? {
        guard let id else { return nil }
        return users[id]
    }

    func chat(_ id: Int64) -> RealChat? {
        chats.first(where: { $0.id == id })
    }

    private func applyUser(_ user: RealUser) {
        users[user.id] = user
        if me?.id == user.id {
            me = user
        } else if me == nil && user.id != 0 && user.firstName.isEmpty == false && user.phone.isEmpty == false {
            me = user
        }
    }

    private func applyStatus(_ status: [String: Any], to user: inout RealUser) {
        switch status["@type"] as? String {
        case "userStatusOnline":
            user.isOnline = true
        case "userStatusOffline":
            user.isOnline = false
            user.lastSeen = int(status["was_online"]) ?? 0
        default:
            user.isOnline = false
        }
    }

    private func parseUser(_ json: [String: Any]) -> RealUser? {
        guard let id = int64(json["id"]) else { return nil }

        var user = users[id] ?? RealUser(id: id)
        user.firstName = json["first_name"] as? String ?? user.firstName
        user.lastName = json["last_name"] as? String ?? user.lastName
        user.phone = json["phone_number"] as? String ?? user.phone

        if let usernames = json["usernames"] as? [String: Any] {
            let editable = usernames["editable_username"] as? String ?? ""
            if !editable.isEmpty {
                user.username = editable
            } else if let active = usernames["active_usernames"] as? [String], let first = active.first {
                user.username = first
            }
        }

        if let photo = json["profile_photo"] as? [String: Any] {
            user.photoFileID = fileID(photo["small"]) ?? fileID(photo["big"])
            user.photoPreview = mini(photo["minithumbnail"])
        }

        user.isPremium = bool(json["is_premium"]) ?? user.isPremium
        if let verification = json["verification_status"] as? [String: Any] {
            user.isVerified = bool(verification["is_verified"]) ?? false
        }
        if let status = json["status"] as? [String: Any] {
            applyStatus(status, to: &user)
        }
        return user
    }

    // MARK: - Чаты

    private func updateChat(_ json: [String: Any]) {
        guard let id = int64(json["id"]) else { return }

        var chat: RealChat
        if let existing = chats.first(where: { $0.id == id }) {
            chat = existing
        } else {
            chat = RealChat(id: id, title: json["title"] as? String ?? "Чат")
        }

        chat.title = json["title"] as? String ?? chat.title

        let type = json["type"] as? [String: Any]
        let typeName = type?["@type"] as? String ?? ""

        chat.isChannel = typeName == "chatTypeSupergroup" && (bool(type?["is_channel"]) ?? false)
        chat.isGroup = typeName == "chatTypeBasicGroup" || (typeName == "chatTypeSupergroup" && !chat.isChannel)
        chat.isPrivate = typeName == "chatTypePrivate" || typeName == "chatTypeSecret"

        if let userID = int64(type?["user_id"]) {
            chat.userID = userID
        }
        if let supergroupID = int64(type?["supergroup_id"]) {
            chat.supergroupID = supergroupID
        }
        if let basicGroupID = int64(type?["basic_group_id"]) {
            chat.basicGroupID = basicGroupID
        }

        if let photo = json["photo"] as? [String: Any] {
            chat.photoFileID = fileID(photo["small"]) ?? fileID(photo["big"])
            chat.photoPreview = mini(photo["minithumbnail"])
        }

        if let last = json["last_message"] as? [String: Any] {
            chat.lastMessageText = previewText(last)
            chat.lastMessageDate = int(last["date"]) ?? 0
            chat.lastMessageID = int64(last["id"]) ?? 0
            chat.lastMessageSenderID = senderUserID(last["sender_id"])
        }

        chat.unreadCount = int(json["unread_count"]) ?? chat.unreadCount
        chat.unreadMentionCount = int(json["unread_mention_count"]) ?? chat.unreadMentionCount
        chat.isMarkedAsUnread = bool(json["is_marked_as_unread"]) ?? chat.isMarkedAsUnread
        chat.lastReadInboxMessageID = int64(json["last_read_inbox_message_id"]) ?? chat.lastReadInboxMessageID
        chat.lastReadOutboxMessageID = int64(json["last_read_outbox_message_id"]) ?? chat.lastReadOutboxMessageID

        if let settings = json["notification_settings"] as? [String: Any] {
            chat.isMuted = isMuted(settings)
        }

        if let positions = json["positions"] as? [[String: Any]] {
            for position in positions {
                let list = position["list"] as? [String: Any]
                if (list?["@type"] as? String) == "chatListMain" {
                    chat.isPinned = bool(position["is_pinned"]) ?? chat.isPinned
                }
            }
        }

        if let index = chats.firstIndex(where: { $0.id == id }) {
            chats[index] = chat
        } else {
            chats.append(chat)
        }
        sortChats()
    }

    private func sortChats() {
        chats.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.lastMessageDate != rhs.lastMessageDate { return lhs.lastMessageDate > rhs.lastMessageDate }
            return lhs.id > rhs.id
        }
    }

    private func isMuted(_ settings: [String: Any]) -> Bool {
        let useDefault = bool(settings["use_default_mute_for"]) ?? true
        let muteFor = int(settings["mute_for"]) ?? 0
        return useDefault ? false : muteFor > 0
    }

    private func updateMemberCount(supergroupID: Int64, count: Int) {
        guard count > 0 else { return }
        for index in chats.indices where chats[index].supergroupID == supergroupID {
            chats[index].memberCount = count
        }
    }

    private func updateMemberCount(basicGroupID: Int64, count: Int) {
        guard count > 0 else { return }
        for index in chats.indices where chats[index].basicGroupID == basicGroupID {
            chats[index].memberCount = count
        }
    }

    // MARK: - Сообщения

    private func handleHistory(_ json: [String: Any]) {
        guard let list = json["messages"] as? [[String: Any]],
              let first = list.first,
              let chatID = int64(first["chat_id"]) else { return }

        let parsed = list.compactMap(parseMessage)
        var current = messages[chatID] ?? []
        let known = Set(current.map { $0.id })
        current.append(contentsOf: parsed.filter { !known.contains($0.id) })
        current.sort { $0.id < $1.id }
        messages[chatID] = current
    }

    private func handleFoundMessages(_ json: [String: Any]) {
        guard let list = json["messages"] as? [[String: Any]] else { return }
        messageSearchResults = list.compactMap(parseMessage)
    }

    private func handleChatSearch(_ json: [String: Any]) {
        guard let ids = json["chat_ids"] as? [NSNumber] else { return }
        let found = ids.map { $0.int64Value }
        searchChatIDs = found

        for id in found where !chats.contains(where: { $0.id == id }) {
            send(["@type": "getChat", "chat_id": id])
        }
    }

    private func upsertMessage(_ message: RealMessage) {
        var list = messages[message.chatID] ?? []
        if let index = list.firstIndex(where: { $0.id == message.id }) {
            list[index] = message
        } else {
            list.append(message)
        }
        list.sort { $0.id < $1.id }
        messages[message.chatID] = list
    }

    private func removeMessage(id: Int64, chatID: Int64) {
        messages[chatID] = (messages[chatID] ?? []).filter { $0.id != id }
    }

    private func updatePreview(with message: RealMessage) {
        guard let index = chats.firstIndex(where: { $0.id == message.chatID }) else { return }
        if message.date >= chats[index].lastMessageDate {
            chats[index].lastMessageText = message.previewText
            chats[index].lastMessageDate = message.date
            chats[index].lastMessageID = message.id
            chats[index].lastMessageSenderID = message.senderUserID
            sortChats()
        }
    }

    private func markMessageFailed(id: Int64, chatID: Int64) {
        guard var list = messages[chatID],
              let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].state = .failed
        messages[chatID] = list
    }

    private func editMessageDate(chatID: Int64, messageID: Int64, date: Int) {
        guard var list = messages[chatID],
              let index = list.firstIndex(where: { $0.id == messageID }) else { return }
        list[index].editDate = date
        messages[chatID] = list
    }

    private func updateMessageContent(chatID: Int64, messageID: Int64, content: [String: Any]) {
        guard var list = messages[chatID],
              let index = list.firstIndex(where: { $0.id == messageID }) else { return }
        var message = list[index]
        applyContent(content, to: &message)
        list[index] = message
        messages[chatID] = list
    }

    private func applyInteraction(_ info: [String: Any], chatID: Int64, messageID: Int64) {
        guard var list = messages[chatID],
              let index = list.firstIndex(where: { $0.id == messageID }) else { return }
        list[index].views = int(info["view_count"]) ?? 0
        messages[chatID] = list

        if let reactions = info["reactions"] as? [String: Any],
           let reactionList = reactions["reactions"] as? [[String: Any]] {
            applyReactions(reactionList, chatID: chatID, messageID: messageID)
        }
    }

    private func applyReactions(_ list: [[String: Any]], chatID: Int64, messageID: Int64) {
        guard var stored = messages[chatID],
              let index = stored.firstIndex(where: { $0.id == messageID }) else { return }
        stored[index].reactions = parseReactions(list)
        messages[chatID] = stored
    }

    private func handleChatAction(_ json: [String: Any]) {
        guard let chatID = int64(json["chat_id"]) else { return }
        let sender = json["sender_id"]
        if senderUserID(sender) == me?.id { return }

        let action = json["action"] as? [String: Any]
        let actionType = action?["@type"] as? String ?? ""

        if actionType == "chatActionCancel" {
            typing[chatID] = nil
            typingTimers[chatID]?.cancel()
            typingTimers[chatID] = nil
            return
        }

        let name = senderName(sender)
        let actionText: String

        switch actionType {
        case "chatActionTyping":
            actionText = "печатает…"
        case "chatActionRecordingVoiceNote":
            actionText = "записывает голосовое…"
        case "chatActionRecordingVideoNote", "chatActionRecordingVideo":
            actionText = "записывает видео…"
        case "chatActionUploadingPhoto":
            actionText = "отправляет фото…"
        case "chatActionUploadingVideo":
            actionText = "отправляет видео…"
        case "chatActionUploadingDocument":
            actionText = "отправляет файл…"
        case "chatActionChoosingSticker":
            actionText = "выбирает стикер…"
        default:
            return
        }

        typing[chatID] = name.isEmpty ? actionText : "\(name) \(actionText)"
        scheduleTypingClear(chatID: chatID)
    }

    private func scheduleTypingClear(chatID: Int64) {
        typingTimers[chatID]?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.typing[chatID] = nil
            self?.typingTimers[chatID] = nil
        }
        typingTimers[chatID] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: item)
    }

    private func senderName(_ sender: Any?) -> String {
        guard let dict = sender as? [String: Any] else { return "" }
        if (dict["@type"] as? String) == "messageSenderUser", let id = int64(dict["user_id"]) {
            return users[id]?.firstName ?? ""
        }
        if (dict["@type"] as? String) == "messageSenderChat", let id = int64(dict["chat_id"]) {
            return chats.first(where: { $0.id == id })?.title ?? ""
        }
        return ""
    }

    // MARK: - Стикеры

    private func parseSticker(_ json: [String: Any]) -> RealSticker? {
        guard let id = int64(json["id"]) else { return nil }

        let file = json["sticker"] as? [String: Any]
        let thumbnail = json["thumbnail"] as? [String: Any]

        return RealSticker(
            id: id,
            fileID: fileID(file) ?? 0,
            remoteID: (file?["remote"] as? [String: Any])?["id"] as? String ?? "",
            emoji: json["emoji"] as? String ?? "🙂",
            width: int(json["width"]) ?? 512,
            height: int(json["height"]) ?? 512,
            format: (json["format"] as? [String: Any])?["@type"] as? String ?? "",
            thumbnailFileID: fileID(thumbnail?["file"])
        )
    }

    // MARK: - Файлы

    private func handleFile(_ json: [String: Any]) {
        guard let file = json["file"] as? [String: Any],
              let id = int32(file["id"]) else { return }

        let local = file["local"] as? [String: Any]
        let completed = bool(local?["is_downloading_completed"]) ?? false
        let path = local?["path"] as? String ?? ""

        if completed && !path.isEmpty {
            if filePaths[id] != path {
                filePaths[id] = path
            }
            downloading.remove(id)
        }
    }

    // MARK: - Парсинг сообщений

    private func parseMessage(_ json: [String: Any]) -> RealMessage? {
        guard let id = int64(json["id"]),
              let chatID = int64(json["chat_id"]) else { return nil }

        var message = RealMessage(
            id: id,
            chatID: chatID,
            senderUserID: senderUserID(json["sender_id"]),
            senderChatID: senderChatID(json["sender_id"]),
            text: "",
            date: int(json["date"]) ?? 0,
            isOutgoing: bool(json["is_outgoing"]) ?? false,
            kind: .text
        )

        message.editDate = int(json["edit_date"]) ?? 0
        message.authorSignature = json["author_signature"] as? String ?? ""

        applyContent(json["content"] as? [String: Any] ?? [:], to: &message)

        if let reply = json["reply_to"] as? [String: Any],
           (reply["@type"] as? String) == "messageReplyToMessage" {
            let replyID = int64(reply["message_id"]) ?? 0
            let replyContent = reply["content"] as? [String: Any] ?? [:]
            message.reply = ReplyPreview(
                messageID: replyID,
                text: previewText(["content": replyContent])
            )
        }

        if let info = json["interaction_info"] as? [String: Any] {
            message.views = int(info["view_count"]) ?? 0
            if let reactions = info["reactions"] as? [String: Any],
               let list = reactions["reactions"] as? [[String: Any]] {
                message.reactions = parseReactions(list)
            }
        }

        if let sending = json["sending_state"] as? [String: Any],
           let stateType = sending["@type"] as? String {
            if stateType == "messageSendingStatePending" {
                message.state = .sending
            } else if stateType == "messageSendingStateFailed" {
                message.state = .failed
            }
        }

        return message
    }

    private func parseReactions(_ list: [[String: Any]]) -> [RealReaction] {
        return list.compactMap { item in
            let type = item["type"] as? [String: Any]
            guard (type?["@type"] as? String) == "reactionTypeEmoji",
                  let emoji = type?["emoji"] as? String else { return nil }
            return RealReaction(
                emoji: emoji,
                count: int(item["total_count"]) ?? 0,
                isChosen: bool(item["is_chosen"]) ?? false
            )
        }
    }

    private func applyContent(_ content: [String: Any], to message: inout RealMessage) {
        let type = content["@type"] as? String ?? ""
        message.mediaFileID = nil
        message.previewFileID = nil
        message.previewData = nil
        message.mediaWidth = 0
        message.mediaHeight = 0
        message.duration = 0
        message.fileName = ""
        message.fileSize = 0
        message.mimeType = ""
        message.stickerEmoji = ""
        message.stickerRemoteID = ""
        message.stickerFormat = ""
        message.waveform = []

        switch type {
        case "messageText":
            message.kind = .text
            message.text = text(content["text"])

        case "messagePhoto":
            message.kind = .photo
            message.text = text(content["caption"])
            if let photo = content["photo"] as? [String: Any] {
                let sizes = (photo["sizes"] as? [[String: Any]] ?? [])
                    .sorted { pixelArea($0) > pixelArea($1) }
                message.mediaFileID = fileID(sizes.first?["photo"])
                message.previewFileID = fileID(sizes.last?["photo"])
                message.previewData = mini(photo["minithumbnail"])
                if let biggest = sizes.first {
                    message.mediaWidth = int(biggest["width"]) ?? 0
                    message.mediaHeight = int(biggest["height"]) ?? 0
                }
            }

        case "messageVideo":
            message.kind = .video
            message.text = text(content["caption"])
            if let video = content["video"] as? [String: Any] {
                message.mediaFileID = fileID(video["video"])
                message.previewFileID = fileID((video["thumbnail"] as? [String: Any])?["file"])
                    ?? fileID((video["cover"] as? [String: Any])?["photo"])
                message.previewData = mini(video["minithumbnail"])
                message.duration = int(video["duration"]) ?? 0
                message.mediaWidth = int(video["width"]) ?? 0
                message.mediaHeight = int(video["height"]) ?? 0
                message.fileName = video["file_name"] as? String ?? ""
                message.mimeType = video["mime_type"] as? String ?? ""
            }

        case "messageAnimation":
            message.kind = .animation
            message.text = text(content["caption"])
            if let animation = content["animation"] as? [String: Any] {
                message.mediaFileID = fileID(animation["animation"])
                message.previewFileID = fileID((animation["thumbnail"] as? [String: Any])?["file"])
                message.previewData = mini(animation["minithumbnail"])
                message.duration = int(animation["duration"]) ?? 0
                message.mediaWidth = int(animation["width"]) ?? 0
                message.mediaHeight = int(animation["height"]) ?? 0
                message.fileName = animation["file_name"] as? String ?? ""
                message.mimeType = animation["mime_type"] as? String ?? ""
            }

        case "messageVoiceNote":
            message.kind = .voice
            message.text = text(content["caption"])
            if let voice = content["voice_note"] as? [String: Any] {
                message.mediaFileID = fileID(voice["voice"])
                message.duration = int(voice["duration"]) ?? 0
                message.mimeType = voice["mime_type"] as? String ?? ""
                message.waveform = waveform(voice["waveform"])
            }

        case "messageVideoNote":
            message.kind = .videoNote
            if let note = content["video_note"] as? [String: Any] {
                message.mediaFileID = fileID(note["video"])
                message.previewFileID = fileID((note["thumbnail"] as? [String: Any])?["file"])
                message.previewData = mini(note["minithumbnail"])
                message.duration = int(note["duration"]) ?? 0
                message.mediaWidth = int(note["length"]) ?? 0
                message.mediaHeight = int(note["length"]) ?? 0
            }

        case "messageDocument":
            message.kind = .document
            message.text = text(content["caption"])
            if let document = content["document"] as? [String: Any] {
                message.mediaFileID = fileID(document["document"])
                message.fileName = document["file_name"] as? String ?? "Файл"
                message.mimeType = document["mime_type"] as? String ?? ""
                message.fileSize = int64((document["document"] as? [String: Any])?["size"]) ?? 0
            }

        case "messageAudio":
            message.kind = .audio
            message.text = text(content["caption"])
            if let audio = content["audio"] as? [String: Any] {
                message.mediaFileID = fileID(audio["audio"])
                message.duration = int(audio["duration"]) ?? 0
                message.fileName = audio["title"] as? String ?? audio["file_name"] as? String ?? "Аудио"
                message.mimeType = audio["mime_type"] as? String ?? ""
                message.fileSize = int64((audio["audio"] as? [String: Any])?["size"]) ?? 0
            }

        case "messageSticker":
            message.kind = .sticker
            if let sticker = content["sticker"] as? [String: Any] {
                message.stickerEmoji = sticker["emoji"] as? String ?? "🙂"
                message.stickerFormat = (sticker["format"] as? [String: Any])?["@type"] as? String ?? ""
                message.isPremiumSticker = bool(content["is_premium"]) ?? false
                message.mediaWidth = int(sticker["width"]) ?? 512
                message.mediaHeight = int(sticker["height"]) ?? 512
                if let file = sticker["sticker"] as? [String: Any] {
                    message.mediaFileID = fileID(file)
                    message.stickerRemoteID = (file["remote"] as? [String: Any])?["id"] as? String ?? ""
                }
                message.previewFileID = fileID((sticker["thumbnail"] as? [String: Any])?["file"])
            }

        case "messageLocation":
            message.kind = .location
            if let location = content["location"] as? [String: Any] {
                message.latitude = double(location["latitude"]) ?? 0
                message.longitude = double(location["longitude"]) ?? 0
            }

        case "messageContact":
            message.kind = .contact
            if let contact = content["contact"] as? [String: Any] {
                let first = contact["first_name"] as? String ?? ""
                let last = contact["last_name"] as? String ?? ""
                let phone = contact["phone_number"] as? String ?? ""
                message.text = "\(first) \(last)\n\(phone)".trimmingCharacters(in: .whitespacesAndNewlines)
            }

        case "messagePoll":
            message.kind = .poll
            if let poll = content["poll"] as? [String: Any] {
                message.text = text(poll["question"])
            }

        default:
            message.kind = .other
            message.text = ""
        }
    }

    private func previewText(_ message: [String: Any]) -> String {
        guard let content = message["content"] as? [String: Any],
              let type = content["@type"] as? String else { return "Сообщение" }

        switch type {
        case "messageText":
            return text(content["text"])
        case "messagePhoto":
            let caption = text(content["caption"])
            return caption.isEmpty ? "📷 Фото" : "📷 \(caption)"
        case "messageVideo":
            return "🎬 Видео"
        case "messageAnimation":
            return "GIF"
        case "messageVoiceNote":
            return "🎤 Голосовое сообщение"
        case "messageVideoNote":
            return "⚪ Видеосообщение"
        case "messageDocument":
            return "📎 \(((content["document"] as? [String: Any])?["file_name"] as? String) ?? "Файл")"
        case "messageAudio":
            return "🎵 Аудио"
        case "messageSticker":
            return (content["sticker"] as? [String: Any])?["emoji"] as? String ?? "Стикер"
        case "messageLocation":
            return "📍 Геопозиция"
        case "messageContact":
            return "👤 Контакт"
        case "messagePoll":
            return "📊 Опрос"
        default:
            return "Сообщение"
        }
    }

    // MARK: - JSON-хелперы

    private func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func int32(_ value: Any?) -> Int32? {
        (value as? NSNumber)?.int32Value
    }

    private func int64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    private func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    private func text(_ value: Any?) -> String {
        guard let dict = value as? [String: Any] else { return "" }
        return dict["text"] as? String ?? ""
    }

    private func fileID(_ value: Any?) -> Int32? {
        guard let dict = value as? [String: Any] else { return nil }
        return int32(dict["id"])
    }

    private func mini(_ value: Any?) -> Data? {
        guard let dict = value as? [String: Any],
              let base64 = dict["data"] as? String else { return nil }
        return Data(base64Encoded: base64)
    }

    private func senderUserID(_ value: Any?) -> Int64? {
        guard let dict = value as? [String: Any],
              (dict["@type"] as? String) == "messageSenderUser" else { return nil }
        return int64(dict["user_id"])
    }

    private func senderChatID(_ value: Any?) -> Int64? {
        guard let dict = value as? [String: Any],
              (dict["@type"] as? String) == "messageSenderChat" else { return nil }
        return int64(dict["chat_id"])
    }

    private func pixelArea(_ size: [String: Any]) -> Int {
        (int(size["width"]) ?? 0) * (int(size["height"]) ?? 0)
    }

    private func waveform(_ value: Any?) -> [CGFloat] {
        guard let base64 = value as? String,
              let data = Data(base64Encoded: base64),
              !data.isEmpty else { return [] }

        return data.prefix(120).map { byte in
            CGFloat(min(Int(byte), 31)) / 31.0
        }
    }
}

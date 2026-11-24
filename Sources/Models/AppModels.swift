import Foundation

// MARK: - Типы сообщений

enum MessageMediaKind: String, Equatable {
    case text
    case photo
    case video
    case animation
    case voice
    case videoNote
    case document
    case audio
    case sticker
    case location
    case contact
    case poll
    case other

    var isMedia: Bool {
        switch self {
        case .photo, .video, .animation, .videoNote:
            return true
        default:
            return false
        }
    }

    var placeholder: String {
        switch self {
        case .photo: return "Фото"
        case .video: return "Видео"
        case .animation: return "GIF"
        case .voice: return "Голосовое сообщение"
        case .videoNote: return "Видеосообщение"
        case .document: return "Файл"
        case .audio: return "Аудио"
        case .sticker: return "Стикер"
        case .location: return "Геопозиция"
        case .contact: return "Контакт"
        case .poll: return "Опрос"
        case .text: return ""
        case .other: return "Сообщение"
        }
    }
}

enum MessageState: String, Equatable {
    case sending
    case sent
    case failed
}

struct RealReaction: Identifiable, Equatable {
    let emoji: String
    let count: Int
    let isChosen: Bool

    var id: String { emoji }
}

struct ReplyPreview: Equatable {
    let messageID: Int64
    let text: String
}

// MARK: - Сообщение

struct RealMessage: Identifiable, Equatable {
    let id: Int64
    let chatID: Int64
    var senderUserID: Int64?
    var senderChatID: Int64?
    var authorSignature: String = ""
    var text: String
    let date: Int
    var editDate: Int = 0
    var isOutgoing: Bool
    var kind: MessageMediaKind
    var mediaFileID: Int32?
    var previewFileID: Int32?
    var previewData: Data?
    var mediaWidth: Int = 0
    var mediaHeight: Int = 0
    var duration: Int = 0
    var fileName: String = ""
    var fileSize: Int64 = 0
    var mimeType: String = ""
    var stickerEmoji: String = ""
    var stickerRemoteID: String = ""
    var stickerFormat: String = ""
    var isPremiumSticker: Bool = false
    var waveform: [CGFloat] = []
    var reply: ReplyPreview?
    var reactions: [RealReaction] = []
    var views: Int = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var state: MessageState = .sent

    var formattedTime: String {
        DateFormatters.time.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }

    var isEdited: Bool { editDate > 0 }

    var canBeEdited: Bool {
        isOutgoing && kind == .text && state == .sent
    }

    var canBeForwarded: Bool {
        state == .sent && kind != .other
    }

    var displayText: String {
        if !text.isEmpty { return text }
        if kind == .location {
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
        return kind.placeholder
    }

    var previewText: String {
        switch kind {
        case .text:
            return text
        case .sticker:
            return stickerEmoji.isEmpty ? "Стикер" : stickerEmoji
        case .photo:
            return text.isEmpty ? "📷 Фото" : "📷 \(text)"
        case .video:
            return "🎬 Видео"
        case .animation:
            return "GIF"
        case .voice:
            return "🎤 Голосовое сообщение"
        case .videoNote:
            return "⚪ Видеосообщение"
        case .document:
            return "📎 \(fileName.isEmpty ? "Файл" : fileName)"
        case .audio:
            return "🎵 \(fileName.isEmpty ? "Аудио" : fileName)"
        case .location:
            return "📍 Геопозиция"
        case .contact:
            return "👤 Контакт"
        case .poll:
            return "📊 \(text)"
        case .other:
            return "Сообщение"
        }
    }

    var emojiOnly: Bool {
        guard kind == .text else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var emojiCount = 0
        for scalar in trimmed.unicodeScalars {
            if scalar.value == 0x200D || scalar.value == 0xFE0F || scalar.value == 0x20E3 {
                continue
            }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            if scalar.properties.isEmojiPresentation {
                emojiCount += 1
                continue
            }
            if scalar.properties.isEmoji && scalar.value > 0x238C {
                emojiCount += 1
                continue
            }
            return false
        }
        return emojiCount > 0 && emojiCount <= 3
    }
}

// MARK: - Чат

struct RealChat: Identifiable, Equatable {
    let id: Int64
    var title: String
    var lastMessageText: String = ""
    var lastMessageDate: Int = 0
    var lastMessageID: Int64 = 0
    var lastMessageSenderID: Int64?
    var unreadCount: Int = 0
    var unreadMentionCount: Int = 0
    var isChannel: Bool = false
    var isGroup: Bool = false
    var isPrivate: Bool = false
    var isVerified: Bool = false
    var isPinned: Bool = false
    var isMuted: Bool = false
    var isMarkedAsUnread: Bool = false
    var photoFileID: Int32?
    var photoPreview: Data?
    var userID: Int64?
    var supergroupID: Int64?
    var basicGroupID: Int64?
    var memberCount: Int = 0
    var onlineCount: Int = 0
    var lastReadOutboxMessageID: Int64 = 0
    var lastReadInboxMessageID: Int64 = 0

    var time: String {
        DateFormatters.chatListTime(lastMessageDate)
    }

    var kindTitle: String {
        if isChannel { return "Канал" }
        if isGroup { return "Группа" }
        if isPrivate { return "Личный чат" }
        return "Чат"
    }

    var subtitle: String {
        if isChannel {
            return memberCount > 0 ? "канал · \(memberCount) подписчиков" : "канал"
        }
        if isGroup {
            if onlineCount > 0 { return "\(onlineCount) в сети" }
            if memberCount > 0 { return "\(memberCount) участников" }
            return "группа"
        }
        return ""
    }
}

// MARK: - Пользователь

struct RealUser: Identifiable, Equatable {
    let id: Int64
    var firstName: String = ""
    var lastName: String = ""
    var username: String = ""
    var phone: String = ""
    var bio: String = ""
    var isOnline: Bool = false
    var lastSeen: Int = 0
    var photoFileID: Int32?
    var photoPreview: Data?
    var isPremium: Bool = false
    var isVerified: Bool = false

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Пользователь" : full
    }

    var handle: String {
        username.isEmpty ? "" : "@\(username)"
    }

    var statusText: String {
        if isOnline { return "в сети" }
        guard lastSeen > 0 else { return "был(а) недавно" }
        return DateFormatters.lastSeen.string(from: Date(timeIntervalSince1970: TimeInterval(lastSeen)))
    }
}

// MARK: - Стикер

struct RealSticker: Identifiable, Equatable {
    let id: Int64
    var fileID: Int32 = 0
    var remoteID: String = ""
    var emoji: String = ""
    var width: Int = 512
    var height: Int = 512
    var format: String = ""
    var thumbnailFileID: Int32?

    var isPlayable: Bool {
        format.localizedCaseInsensitiveContains("tgs") || format.localizedCaseInsensitiveContains("webm")
    }
}

// MARK: - Группировка сообщений по дням

struct MessageDay: Identifiable {
    let id: String
    let date: Date
    let messages: [RealMessage]

    static func group(_ messages: [RealMessage]) -> [MessageDay] {
        let calendar = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [RealMessage]] = [:]

        for message in messages {
            let day = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(message.date)))
            if buckets[day] == nil {
                buckets[day] = []
                order.append(day)
            }
            buckets[day]?.append(message)
        }

        return order.map { day in
            MessageDay(
                id: String(day.timeIntervalSince1970),
                date: day,
                messages: (buckets[day] ?? []).sorted { $0.id < $1.id }
            )
        }
    }
}

// MARK: - Форматтеры

enum DateFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let chatList: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    static let lastSeen: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    static func chatListTime(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return time.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "вчера"
        }
        return shortDate.string(from: date)
    }

    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInYesterday(date) { return "Вчера" }
        return dayHeader.string(from: date)
    }
}

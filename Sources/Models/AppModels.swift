import Foundation

struct RealChat: Identifiable, Equatable {
    let id: Int64
    var title: String
    var lastMessage: String
    var lastMessageDate: Int
    var unreadCount: Int
    var isChannel: Bool = false
    var isGroup: Bool = false

    /// Время последнего сообщения: «14:05», «вчера» или «12.11.26».
    var time: String {
        guard lastMessageDate > 0 else { return "" }

        let date = Date(timeIntervalSince1970: TimeInterval(lastMessageDate))
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "вчера"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter.string(from: date)
    }
}

struct RealMessage: Identifiable, Equatable {
    let id: Int64
    let text: String
    let date: Int
    let isOutgoing: Bool

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date)))
    }
}

import Foundation

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
}

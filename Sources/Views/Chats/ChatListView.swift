import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var tdlib: TDLibManager
    
    var body: some View {
        NavigationStack {
            List(tdlib.chats) { chat in
                ChatCell(chat: chat)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Чаты")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
}

struct ChatCell: View {
    let chat: RealChat
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(LinearGradient(colors: [.green, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .overlay(Text(String(chat.title.prefix(1))).bold().foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title).font(.headline).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text(chat.time).font(.caption).foregroundColor(.gray)
                }
                Text(chat.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}

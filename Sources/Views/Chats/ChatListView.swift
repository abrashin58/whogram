import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @State private var searchText = ""
    @State private var selectedFolder = "Все"

    let folders = ["Все", "Личное", "Работа", "Каналы"]

    var filteredChats: [RealChat] {
        tdlib.chats.filter { chat in
            searchText.isEmpty || chat.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Поиск", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(folders, id: \.self) { folder in
                                Text(folder)
                                    .fontWeight(selectedFolder == folder ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFolder == folder ? Color.green.opacity(0.2) : Color.clear)
                                    .foregroundColor(selectedFolder == folder ? .green : .gray)
                                    .cornerRadius(20)
                                    .onTapGesture {
                                        withAnimation { selectedFolder = folder }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 10)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredChats) { chat in
                                NavigationLink(destination: ChatDetailView(chat: chat)) {
                                    ChatCell(chat: chat)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct ChatCell: View {
    let chat: RealChat
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(LinearGradient(colors: [Color.gray.opacity(0.5), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(Text(String(chat.title.prefix(1))).font(.title3.bold()).foregroundColor(.white))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.title).font(.headline).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text(chat.time).font(.caption).foregroundColor(.gray)
                }
                HStack {
                    Text(chat.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}

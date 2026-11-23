import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var tdlib: TDLibManager

    @State private var searchText = ""
    @State private var selectedFolder = "Все"

    private let folders = ["Все", "Личные", "Группы", "Каналы"]

    private var filteredChats: [RealChat] {
        tdlib.chats.filter { chat in
            matchesFolder(chat) &&
            (searchText.isEmpty || chat.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    folderBar

                    if filteredChats.isEmpty {
                        emptyState
                    } else {
                        chatsList
                    }
                }
            }
            .navigationTitle("Чаты")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Поиск", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var folderBar: some View {
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { selectedFolder = folder }
                        }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
    }

    private var chatsList: some View {
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.6))
            Text(emptyStateText)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateText: String {
        if tdlib.chats.isEmpty {
            return "Загрузка чатов…\nЕсли список пуст долго — проверьте подключение"
        }
        if !searchText.isEmpty {
            return "По запросу «\(searchText)» ничего не найдено"
        }
        return "В этой папке нет чатов"
    }

    private func matchesFolder(_ chat: RealChat) -> Bool {
        switch selectedFolder {
        case "Личные":
            return !chat.isGroup && !chat.isChannel
        case "Группы":
            return chat.isGroup
        case "Каналы":
            return chat.isChannel
        default:
            return true
        }
    }
}

struct ChatCell: View {
    let chat: RealChat

    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.gray.opacity(0.5), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(chat.title.prefix(1)))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
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
                    Spacer(minLength: 8)
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

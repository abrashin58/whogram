import SwiftUI

struct SearchView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    var onOpenChat: (Int64) -> Void

    @State private var query = ""
    @State private var debounce: DispatchWorkItem?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [RealChat] {
        guard !trimmedQuery.isEmpty else { return tdlib.mainChats }

        var merged: [RealChat] = []
        var seen = Set<Int64>()

        for id in tdlib.searchChatIDs {
            if let chat = tdlib.chat(id), !seen.contains(id) {
                merged.append(chat)
                seen.insert(id)
            }
        }

        for chat in tdlib.chats where chat.title.localizedCaseInsensitiveContains(trimmedQuery) {
            if !seen.contains(chat.id) {
                merged.append(chat)
                seen.insert(chat.id)
            }
        }

        return merged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackdrop()

                VStack(spacing: 0) {
                    header
                    searchField

                    if results.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Поиск")
                    .font(theme.font(30, weight: .bold))
                    .foregroundStyle(theme.accent.gradient)
                Text("Чаты, группы и каналы")
                    .font(theme.font(12))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            TextField("Введите название", text: $query)
                .font(theme.font(14))
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !query.isEmpty {
                Button {
                    query = ""
                    tdlib.searchChats("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.field)
        )
        .padding(.horizontal, 18)
        .onChange(of: query) { value in
            debounce?.cancel()

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            tdlib.searchChats("")
            guard !trimmed.isEmpty else { return }

            let item = DispatchWorkItem {
                tdlib.searchChats(trimmed)
            }
            debounce = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
        }
        .onDisappear { debounce?.cancel() }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if trimmedQuery.isEmpty {
                    Text("Недавние чаты")
                        .font(theme.font(11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                ForEach(results) { chat in
                    Button {
                        onOpenChat(chat.id)
                    } label: {
                        ChatRow(
                            chat: chat,
                            preview: chat.lastMessageText.isEmpty ? chat.kindTitle : chat.lastMessageText
                        )
                    }
                    .buttonStyle(ThemePressStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            ThemeEmptyState(icon: "magnifyingglass",
                            title: trimmedQuery.isEmpty ? "Поиск в Telegram" : "Ничего не найдено",
                            detail: trimmedQuery.isEmpty ? "Введите название чата, группы или канала." : "Попробуйте другое название.")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    @State private var tab: MainTab = .chats
    @State private var chatsPath = NavigationPath()
    @State private var toast: String?

    enum MainTab: String, CaseIterable, Identifiable {
        case chats
        case search
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .chats: return "Чаты"
            case .search: return "Поиск"
            case .settings: return "Настройки"
            }
        }

        var icon: String {
            switch self {
            case .chats: return "bubble.left.and.bubble.right.fill"
            case .search: return "magnifyingglass"
            case .settings: return "gearshape.fill"
            }
        }
    }

    private var totalUnread: Int {
        tdlib.chats.reduce(0) { $0 + ($1.isMuted ? 0 : $1.unreadCount) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .chats:
                    ChatListView(path: $chatsPath, onOpenSettings: {
                        withAnimation(.easeInOut(duration: 0.2)) { tab = .settings }
                    })
                case .search:
                    SearchView { id in
                        chatsPath = NavigationPath()
                        chatsPath.append(id)
                        withAnimation(.easeInOut(duration: 0.2)) { tab = .chats }
                    }
                case .settings:
                    SettingsView()
                }
            }
            .padding(.bottom, chatsPath.isEmpty ? 74 : 0)

            if chatsPath.isEmpty {
                tabBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(toast)
                        .font(theme.font(12, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(theme.card)
                )
                .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 1))
                .padding(.top, 6)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: tdlib.errorMessage) { value in
            guard let value else { return }
            withAnimation(.easeOut(duration: 0.2)) { toast = value }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if toast == value {
                    withAnimation(.easeOut(duration: 0.2)) { toast = nil }
                }
                if tdlib.errorMessage == value {
                    tdlib.errorMessage = nil
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        tab = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))

                            if item == .chats && totalUnread > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 4, y: -2)
                            }
                        }

                        if tab == item {
                            Text(item.title)
                                .font(theme.font(12, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(tab == item ? theme.accent.main : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(tab == item ? theme.accent.main.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .background(theme.card.opacity(0.72))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)
    }
}

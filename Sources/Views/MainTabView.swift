import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: MainTab = .chats
    @State private var chatsPath = NavigationPath()
    @State private var toast: String?

    enum MainTab: String, CaseIterable, Identifiable {
        case chats
        case search
        case design
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .chats: return "Чаты"
            case .search: return "Поиск"
            case .design: return "Design Lab"
            case .settings: return "Настройки"
            }
        }

        var icon: String {
            switch self {
            case .chats: return "bubble.left.and.bubble.right.fill"
            case .search: return "magnifyingglass"
            case .design: return "paintpalette.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    private var totalUnread: Int {
        tdlib.mainChats.reduce(0) { $0 + ($1.isMuted ? 0 : $1.unreadCount) }
    }

    var body: some View {
        Group {
            Group {
                switch tab {
                case .chats:
                    ChatListView(path: $chatsPath, onOpenSettings: {
                        select(.settings)
                    })
                case .search:
                    SearchView { id in
                        chatsPath = NavigationPath()
                        chatsPath.append(id)
                        select(.chats)
                    }
                case .design:
                    NavigationStack { AppearanceView() }
                case .settings:
                    SettingsView()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab != .chats || chatsPath.isEmpty {
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
            }
        }
        .background(ThemeBackdrop())
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
            } else if !tdlib.isSessionReady {
                Label(tdlib.statusMessage, systemImage: "arrow.trianglehead.clockwise")
                    .font(theme.smallFont)
                    .padding(8)
                    .background(theme.card, in: Capsule())
                    .allowsHitTesting(false)
            } else if let notice = tdlib.networkNotice {
                Label(notice, systemImage: "antenna.radiowaves.left.and.right")
                    .font(theme.smallFont)
                    .padding(8)
                    .background(theme.card, in: Capsule())
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: tdlib.errorMessage) { value in
            guard let value else { return }
            withAnimation(theme.animation(.easeOut(duration: 0.2), reduced: reduceMotion)) { toast = value }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if toast == value {
                    withAnimation(theme.animation(.easeOut(duration: 0.2), reduced: reduceMotion)) { toast = nil }
                }
                if tdlib.errorMessage == value {
                    tdlib.errorMessage = nil
                }
            }
        }
    }

    private func select(_ item: MainTab) {
        withAnimation(theme.animation(.spring(response: 0.32, dampingFraction: 0.86), reduced: reduceMotion)) {
            tab = item
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { item in
                Button {
                    select(item)
                } label: {
                    VStack(spacing: 4) {
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

                        Text(item.title)
                            .font(theme.font(10, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(tab == item ? theme.accent.onAccent : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background {
                        if tab == item { Capsule().fill(.clear).accentSurface(Capsule()) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(ThemePressStyle())
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityValue(item == .chats && totalUnread > 0 ? "\(totalUnread) непрочитанных" : "")
            }
        }
        .padding(6)
        .liquidGlass(corner: theme.radius + 6)
    }
}

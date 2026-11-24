import SwiftUI
import UIKit

struct ChatInfoView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let chat: RealChat

    @State private var showClearConfirm = false

    private var live: RealChat {
        tdlib.chat(chat.id) ?? chat
    }

    private var user: RealUser? {
        tdlib.user(live.userID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AvatarView(
                        title: live.title,
                        fileID: live.photoFileID ?? user?.photoFileID,
                        preview: live.photoPreview ?? user?.photoPreview,
                        size: 96,
                        isOnline: user?.isOnline ?? false
                    )
                    .padding(.top, 8)

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text(live.title)
                                .font(theme.font(22, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                                .multilineTextAlignment(.center)

                            if live.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.accent.main)
                            }
                        }

                        Text(subtitle)
                            .font(theme.font(12))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let user, live.isPrivate {
                        infoCard(rows: [
                            ("Телефон", user.phone.isEmpty ? "скрыт" : user.phone),
                            ("Username", user.handle.isEmpty ? "нет" : user.handle),
                            ("Статус", user.statusText)
                        ])
                    }

                    actionGrid

                    if !live.isPrivate {
                        infoCard(rows: [
                            ("Участников", live.memberCount > 0 ? "\(live.memberCount)" : "—"),
                            ("В сети", live.onlineCount > 0 ? "\(live.onlineCount)" : "—"),
                            ("Тип", live.kindTitle)
                        ])
                    }

                    Button {
                        showClearConfirm = true
                    } label: {
                        Text("Очистить историю")
                            .font(theme.font(14, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)

                    Text("Чат ID: \(live.id)")
                        .font(theme.font(10))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                .padding(20)
            }
            .background(ThemeBackdrop())
            .navigationTitle("Информация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(theme.accent.main)
                }
            }
            .alert("Очистить историю?", isPresented: $showClearConfirm) {
                Button("Отмена", role: .cancel) { }
                Button("Очистить", role: .destructive) {
                    tdlib.clearHistory(live)
                    dismiss()
                }
            } message: {
                Text("Сообщения будут удалены только у вас.")
            }
            .onAppear {
                tdlib.requestChatInfo(live)
            }
        }
    }

    private var subtitle: String {
        if live.isPrivate, let user {
            return user.statusText
        }
        if live.isChannel { return live.subtitle }
        if live.isGroup { return live.subtitle }
        return live.kindTitle
    }

    private var actionGrid: some View {
        HStack(spacing: 10) {
            actionButton(
                title: live.isPinned ? "Открепить" : "Закрепить",
                icon: "pin.fill",
                active: live.isPinned
            ) {
                tdlib.togglePin(live)
            }

            actionButton(
                title: live.isMuted ? "Включить звук" : "Без звука",
                icon: live.isMuted ? "bell.slash.fill" : "bell.fill",
                active: live.isMuted
            ) {
                tdlib.toggleMute(live)
            }

            actionButton(
                title: "Прочитано",
                icon: "checkmark.circle.fill",
                active: false
            ) {
                tdlib.markAsRead(live)
            }
        }
    }

    private func actionButton(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(active ? theme.accent.onAccent : theme.accent.main)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(active ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(theme.accent.main.opacity(0.14)))
                    )

                Text(title)
                    .font(theme.font(10, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .liquidGlass(corner: theme.radius)
        }
        .buttonStyle(.plain)
    }

    private func infoCard(rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                HStack {
                    Text(rows[index].0)
                        .font(theme.font(13))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(rows[index].1)
                        .font(theme.font(13, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if index < rows.count - 1 {
                    Divider()
                        .overlay(theme.separator)
                }
            }
        }
        .liquidGlass(corner: theme.radius)
    }
}

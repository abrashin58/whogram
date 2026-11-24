import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    @State private var showLogout = false
    @State private var showProfileEditor = false

    private var meName: String {
        tdlib.me?.displayName ?? "Профиль"
    }

    private var meSubtitle: String {
        if let handle = tdlib.me?.handle, !handle.isEmpty {
            return handle
        }
        if let phone = tdlib.me?.phone, !phone.isEmpty {
            return phone
        }
        return "Нажмите, чтобы изменить профиль"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackdrop()

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        profileCard

                        section(title: "Оформление") {
                            NavigationLink {
                                AppearanceView()
                            } label: {
                                settingRow(
                                    icon: "paintpalette.fill",
                                    color: theme.accent.main,
                                    title: "Design Lab",
                                    value: theme.preset.title
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(theme.separator)

                            NavigationLink {
                                AppearanceView(destination: .wallpaper)
                            } label: {
                                settingRow(icon: "photo.on.rectangle", color: Color(hex: 0x8E7CFF),
                                           title: "Обои чата", value: theme.wallpaper.title)
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(theme.separator)

                            NavigationLink {
                                AppearanceView(destination: .typography)
                            } label: {
                                settingRow(
                                    icon: "textformat.size",
                                    color: Color(hex: 0x38C9A0),
                                    title: "Размер текста",
                                    value: "\(Int(theme.fontScale * 100))%"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        section(title: "Аккаунт") {
                            infoRow("Телефон", tdlib.me?.phone ?? "—")
                            Divider().overlay(theme.separator)
                            infoRow("Username", tdlib.me?.handle ?? "—")
                            Divider().overlay(theme.separator)
                            infoRow("Статус", tdlib.statusMessage)

                            Divider().overlay(theme.separator)

                            Button {
                                tdlib.disconnectToAccounts()
                            } label: {
                                settingRow(icon: "person.2", color: theme.accent.main,
                                           title: "Сменить или добавить аккаунт",
                                           value: tdlib.closeRequested ? "Закрываем…" : (tdlib.sessionTitle ?? ""))
                            }
                            .buttonStyle(.plain)
                            .disabled(!tdlib.isSessionReady)
                            if let error = tdlib.errorMessage {
                                Text(error)
                                    .font(theme.smallFont)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 14)
                            }
                            Divider().overlay(theme.separator)

                            Button {
                                showLogout = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Выйти только из Whogram")
                                        .font(theme.font(14, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                            .disabled(!tdlib.isSessionReady)
                        }

                        section(title: "О приложении") {
                            infoRow("Приложение", "Whogram \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")")
                            Divider().overlay(theme.separator)
                            infoRow("TDLib", "1.8.70")
                            Divider().overlay(theme.separator)
                            infoRow("Тема", "\(theme.preset.title) · \(theme.appearance.title)")
                        }

                        Text("Сделано на SwiftUI + TDLib")
                            .font(theme.font(10))
                            .foregroundColor(theme.textSecondary.opacity(0.65))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfileEditor) {
                EditProfileView()
            }
            .alert("Выйти только из Whogram?", isPresented: $showLogout) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    tdlib.logOut()
                }
            } message: {
                Text("Завершится текущий сеанс Whogram, и TDLib очистит его локальные данные. Чтобы сохранить сеанс, выберите «Сменить или добавить аккаунт».")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Настройки")
                    .font(theme.font(30, weight: .bold))
                    .foregroundStyle(theme.accent.gradient)
                Text("Профиль, оформление и аккаунт")
                    .font(theme.font(12))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var profileCard: some View {
        Button {
            showProfileEditor = true
        } label: {
            HStack(spacing: 14) {
                AvatarView(
                    title: meName,
                    fileID: tdlib.me?.photoFileID,
                    preview: tdlib.me?.photoPreview,
                    size: 62,
                    isOnline: tdlib.isAuthorized
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(meName)
                        .font(theme.font(18, weight: .bold))
                        .foregroundColor(theme.accent.onAccent)
                        .lineLimit(1)

                    Text(meSubtitle)
                        .font(theme.font(12))
                        .foregroundColor(theme.accent.onAccent.opacity(0.78))
                        .lineLimit(1)

                    Text("Изменить профиль")
                        .font(theme.font(11, weight: .semibold))
                        .foregroundColor(theme.accent.onAccent)
                        .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent.onAccent.opacity(0.8))
            }
            .padding(16)
            .accentSurface(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        }
        .buttonStyle(ThemePressStyle())
    }

    private func settingIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.16))
            )
    }

    private func settingRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            settingIcon(icon, color: color)
            Text(title)
                .font(theme.font(14))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .font(theme.font(12))
                .foregroundColor(theme.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(theme.font(14))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .font(theme.font(12))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(theme.font(10, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                content()
            }
            .liquidGlass(corner: theme.radius)
        }
    }
}

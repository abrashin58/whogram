import SwiftUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var loaded = false

    private var meName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Профиль" : full
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        AvatarView(
                            title: meName,
                            fileID: tdlib.me?.photoFileID,
                            preview: tdlib.me?.photoPreview,
                            size: 88
                        )
                        .padding(.top, 10)

                        field("Имя", text: $firstName)
                        field("Фамилия", text: $lastName)
                        field("Username", text: $username, keyboard: .twitter)
                        field("О себе", text: $bio)

                        Button {
                            tdlib.saveProfile(
                                firstName: firstName,
                                lastName: lastName,
                                username: username.trimmingCharacters(in: .whitespaces),
                                bio: bio
                            )
                            dismiss()
                        } label: {
                            Text("Сохранить")
                                .font(theme.font(15, weight: .semibold))
                                .foregroundColor(theme.accent.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(theme.accent.gradient)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)

                        Text("Telegram сам проверит username. Если он занят, придёт ошибка.")
                            .font(theme.font(10))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let me = tdlib.me else { return }
        firstName = me.firstName
        lastName = me.lastName
        username = me.username
        bio = tdlib.myBio
        loaded = true
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(theme.font(11, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.leading, 4)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .font(theme.textFont)
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .twitter ? .never : .sentences)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.field)
                )
        }
    }
}

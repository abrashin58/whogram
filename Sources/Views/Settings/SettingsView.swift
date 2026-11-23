import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundColor(.green)

                    Text("Whogram")
                        .foregroundColor(.white)
                        .font(.title2.bold())

                    HStack(spacing: 8) {
                        Circle()
                            .fill(tdlib.isAuthorized ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(tdlib.statusMessage)
                            .foregroundColor(.gray)
                            .font(.footnote)
                    }

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Text("Выйти из аккаунта")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(14)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 30)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Настройки")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "Выйти из аккаунта?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Выйти", role: .destructive) {
                    tdlib.logOut()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Придётся заново ввести номер телефона и код.")
            }
        }
    }
}

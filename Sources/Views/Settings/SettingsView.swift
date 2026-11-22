import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text("Настройки профиля")
                        .foregroundColor(.white)
                        .font(.title2)
                    Text("Раздел будет расширен на Этапе 5")
                        .foregroundColor(.gray)
                        .font(.footnote)
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Настройки")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

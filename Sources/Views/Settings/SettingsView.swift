import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding()
                    
                    Text("Настройки профиля")
                        .foregroundColor(.white)
                        .font(.title2)
                    
                    Spacer()
                }
            }
            .navigationTitle("Настройки")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

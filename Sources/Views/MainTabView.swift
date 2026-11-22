import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatListView()
                .tabItem {
                    Label("Чаты", systemImage: "message.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
        }
        .tint(.green)
    }
}

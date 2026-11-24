import SwiftUI

@main
struct WhogramApp: App {
    @StateObject private var tdlibManager = TDLibManager.shared
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(tdlibManager)
                .environmentObject(themeManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    @State private var showSplash = true

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if tdlib.isAuthorized {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(theme.appearance.colorScheme)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

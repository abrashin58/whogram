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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSplash = true

    var body: some View {
        ZStack {
            ThemeBackdrop()

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
        .tint(theme.accent.main)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + (theme.animations && !reduceMotion ? 0.7 : 0)) {
                withAnimation(theme.animation(.easeInOut(duration: 0.3), reduced: reduceMotion)) {
                    showSplash = false
                }
            }
        }
    }
}

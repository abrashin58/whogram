import SwiftUI

@main
struct WhogramApp: App {
    @StateObject private var tdlibManager = TDLibManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(tdlibManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if tdlib.isAuthorized {
                MainTabView()
            } else {
                LoginView()
            }
            
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}

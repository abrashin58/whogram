import SwiftUI
import UIKit
import Combine

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
    @Environment(\.scenePhase) private var scenePhase
    @State private var firstActivation = true

    var body: some View {
        ZStack {
            ThemeBackdrop()

            if tdlib.isAuthorized {
                MainTabView()
                    .id(tdlib.selectedProfileID)
                    .transition(.opacity)
            } else if firstActivation || tdlib.isRestoringSession {
                SplashView(status: tdlib.isRestoringSession ? tdlib.statusMessage : "Открываем Whogram…")
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(theme.appearance.colorScheme)
        .tint(theme.accent.main)
        .animation(theme.animation(.easeInOut(duration: 0.24), reduced: reduceMotion), value: tdlib.isAuthorized)
        .onAppear { updateScene(scenePhase) }
        .onChange(of: scenePhase) { updateScene($0) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            if scenePhase == .active { updateScene(.active) }
        }
    }

    private func updateScene(_ phase: ScenePhase) {
        tdlib.setForeground(phase == .active)
        if phase == .active { firstActivation = false }
    }
}

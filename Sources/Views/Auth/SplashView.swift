import SwiftUI

struct SplashView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            ThemeBackdrop()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.clear)
                        .frame(width: 92, height: 92)
                        .accentSurface(Circle())

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(theme.accent.onAccent)
                        .offset(x: -2, y: 1)
                }
                .scaleEffect(animate ? 1 : 0.82)

                Text("Whogram")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent.gradient)

                Text("powered by TDLib")
                    .font(theme.font(11))
                    .foregroundColor(theme.textSecondary)
            }
            .opacity(animate ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(theme.animation(.easeOut(duration: 0.55), reduced: reduceMotion)) {
                animate = true
            }
        }
    }
}

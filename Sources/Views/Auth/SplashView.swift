import SwiftUI

struct SplashView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var animate = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            Circle()
                .fill(theme.accent.main.opacity(0.32))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(y: -90)
                .scaleEffect(animate ? 1.08 : 0.85)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.accent.gradient)
                        .frame(width: 92, height: 92)
                        .shadow(color: theme.accent.main.opacity(0.5), radius: 28, y: 12)

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
            withAnimation(.easeOut(duration: 0.9)) {
                animate = true
            }
        }
    }
}

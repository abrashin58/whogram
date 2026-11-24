import SwiftUI

struct SplashView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    let status: String

    var body: some View {
        ZStack {
            ThemeBackdrop()

            VStack(spacing: 14) {
                ZStack {
                    if theme.animations && !reduceMotion {
                        Circle()
                            .trim(from: 0, to: 0.24)
                            .stroke(theme.accent.main.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 115, height: 115)
                            .rotationEffect(.degrees(animate ? 320 : -95))
                    }
                    Circle()
                        .fill(.clear)
                        .frame(width: 92, height: 92)
                        .accentSurface(Circle())

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(theme.accent.onAccent)
                        .offset(x: -2, y: 1)
                }
                .frame(height: 120)
                .scaleEffect(animate || reduceMotion || !theme.animations ? 1 : 0.9)

                Text("Whogram")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent.gradient)

                Text(status)
                    .font(theme.smallFont)
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 24)
                ProgressView().tint(theme.accent.main).accessibilityHidden(true)
            }
        }
        .onAppear {
            withAnimation(theme.animation(.easeOut(duration: 0.9), reduced: reduceMotion)) {
                animate = true
            }
        }
    }
}

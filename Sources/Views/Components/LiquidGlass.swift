import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var corner: CGFloat = 16

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        if theme.profile.surface == .glass && !reduceTransparency {
            if #available(iOS 26.0, *) {
                content
                    .background(theme.card.opacity(0.44), in: shape)
                    .glassEffect(.regular, in: shape)
            } else {
                content
                    .background(.regularMaterial, in: shape)
                    .background(theme.card, in: shape)
                    .overlay(shape.strokeBorder(theme.separator))
            }
        } else {
            content
                .background(theme.card, in: shape)
                .overlay(shape.strokeBorder(theme.separator))
        }
    }
}

extension View {
    func liquidGlass(corner: CGFloat = 16) -> some View {
        modifier(LiquidGlassModifier(corner: corner))
    }

    func accentSurface<S: InsettableShape>(_ shape: S) -> some View {
        modifier(AccentSurfaceModifier(shape: shape))
    }
}

struct AccentSurfaceModifier<S: InsettableShape>: ViewModifier {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S

    func body(content: Content) -> some View {
        let neon = theme.profile.surface == .neon
        return content
            .background(theme.accent.gradient, in: shape)
            .overlay {
                if neon {
                    shape.strokeBorder(.black, lineWidth: 3)
                    shape.inset(by: 3).strokeBorder(.white.opacity(0.28), lineWidth: 0.75)
                }
            }
            .shadow(color: theme.accent.secondary.opacity(neon && !reduceTransparency ? theme.glow : 0),
                    radius: 12, y: 4)
    }
}

struct ThemePressStyle: ButtonStyle {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && theme.animations && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(theme.animation(.spring(response: 0.26, dampingFraction: 0.72), reduced: reduceMotion),
                       value: configuration.isPressed)
    }
}

struct ThemeBackdrop: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .top) {
            theme.background
            if theme.glow > 0 && !reduceTransparency {
                RadialGradient(colors: [theme.accent.secondary.opacity(theme.glow * 0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 290)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MessageSurface: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let outgoing: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.bubbleCorner, style: .continuous)
        let neon = outgoing && theme.profile.surface == .neon
        if outgoing {
            shape.fill(theme.outgoingGradient)
                .overlay(shape.strokeBorder(theme.outgoingText.opacity(neon ? 0.85 : (theme.profile.outlinedBubbles == true ? 0.35 : 0)), lineWidth: neon ? 2 : 1))
                .shadow(color: theme.accent.secondary.opacity(neon && !reduceTransparency ? theme.glow * 0.6 : 0),
                        radius: 6, y: 2)
        } else if theme.bubbleStyle == .glass && !reduceTransparency && theme.profile.incomingColor == nil {
            shape.fill(.regularMaterial)
                .background(theme.incomingBubble.opacity(0.75), in: shape)
                .overlay(shape.strokeBorder(theme.separator))
        } else {
            shape.fill(theme.incomingBubble)
                .overlay(shape.strokeBorder(theme.incomingText.opacity(theme.profile.outlinedBubbles == true ? 0.30 : 0)))
        }
    }
}

struct ThemeEmptyState: View {
    @EnvironmentObject private var theme: ThemeManager
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(theme.accent.main)
                .frame(width: 62, height: 62)
                .liquidGlass(corner: 20)
                .accessibilityHidden(true)
            Text(title).font(theme.font(17, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text(detail).font(theme.smallFont).foregroundStyle(theme.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}

struct ChatSkeleton: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle().fill(theme.separator).frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(theme.separator).frame(width: index.isMultiple(of: 2) ? 128 : 82, height: 9)
                        Capsule().fill(theme.separator).frame(width: index.isMultiple(of: 2) ? 190 : 142, height: 7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(theme.card, in: RoundedRectangle(cornerRadius: theme.radius))
            }
        }
        .opacity(dim ? 0.65 : 1)
        .onAppear {
            if let animation = theme.animation(.easeInOut(duration: 0.85), reduced: reduceMotion) {
                withAnimation(animation.repeatForever(autoreverses: true)) { dim = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Загрузка")
    }
}

import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    @EnvironmentObject var theme: ThemeManager
    var corner: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(theme.card.opacity(0.55))
            .cornerRadius(corner)
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func liquidGlass(corner: CGFloat = 16) -> some View {
        modifier(LiquidGlassModifier(corner: corner))
    }
}

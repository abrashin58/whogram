import SwiftUI

struct AvatarView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    let title: String
    var fileID: Int32?
    var preview: Data?
    var size: CGFloat = 54
    var isOnline = false
    var highlight = false

    private var initials: String {
        let words = title.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if fileID != nil || preview != nil {
                    TdImage(fileID: fileID, previewFileID: nil, previewData: preview, priority: 16)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(theme.avatarGradient(for: title))
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(
                        highlight ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(Color.clear),
                        lineWidth: 2
                    )
            )

            if isOnline {
                Circle()
                    .fill(Color(hex: 0x3DDC84))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(
                        Circle()
                            .stroke(theme.background, lineWidth: 2)
                    )
                    .offset(x: size * 0.01, y: size * 0.01)
            }
        }
        .frame(width: size, height: size)
    }
}

struct WallpaperView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.wallpaperColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if theme.wallpaper != .plain && theme.glow > 0 && !reduceTransparency {
                RadialGradient(colors: [theme.accent.secondary.opacity(theme.glow * theme.profile.wallpaperStrength), .clear],
                               center: .bottomTrailing, startRadius: 0, endRadius: 320)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

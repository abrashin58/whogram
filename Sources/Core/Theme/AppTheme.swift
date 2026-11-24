import SwiftUI
import UIKit

// MARK: - Цвета

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Цвет, который сам переключается между тёмной и светлой темой.
    static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - Акцентные палитры

enum AccentPalette: String, CaseIterable, Identifiable {
    case neon
    case ocean
    case violet
    case sunset
    case amber
    case crimson
    case mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neon: return "Неон"
        case .ocean: return "Океан"
        case .violet: return "Фиалка"
        case .sunset: return "Закат"
        case .amber: return "Янтарь"
        case .crimson: return "Кармин"
        case .mint: return "Мята"
        }
    }

    var colors: [Color] {
        switch self {
        case .neon:
            return [Color(hex: 0x66F5A0), Color(hex: 0x12B76A)]
        case .ocean:
            return [Color(hex: 0x4FACFE), Color(hex: 0x2A6BF2)]
        case .violet:
            return [Color(hex: 0xA78BFA), Color(hex: 0x6D28D9)]
        case .sunset:
            return [Color(hex: 0xFF8A65), Color(hex: 0xE0245E)]
        case .amber:
            return [Color(hex: 0xFFD166), Color(hex: 0xF59E0B)]
        case .crimson:
            return [Color(hex: 0xFF6B6B), Color(hex: 0xC81E5B)]
        case .mint:
            return [Color(hex: 0x7CF5D0), Color(hex: 0x0E9F8A)]
        }
    }

    var main: Color { colors[0] }
    var secondary: Color { colors[1] }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Тёмный текст для светлых палитр.
    var onAccent: Color {
        switch self {
        case .neon, .amber, .mint:
            return Color(hex: 0x08130D)
        case .ocean, .violet, .sunset, .crimson:
            return .white
        }
    }
}

// MARK: - Тема оформления

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Тёмная"
        case .light: return "Светлая"
        case .system: return "Системная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

enum BubbleStyle: String, CaseIterable, Identifiable {
    case modern
    case glass
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern: return "Современные"
        case .glass: return "Стекло"
        case .classic: return "Классика"
        }
    }
}

enum ChatWallpaper: String, CaseIterable, Identifiable {
    case aurora
    case midnight
    case ocean
    case sunset
    case graphite
    case blossom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: return "Аврора"
        case .midnight: return "Полночь"
        case .ocean: return "Глубина"
        case .sunset: return "Тепло"
        case .graphite: return "Графит"
        case .blossom: return "Сакура"
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            return [Color(hex: 0x0B1220), Color(hex: 0x161031), Color(hex: 0x0A1A17)]
        case .midnight:
            return [Color(hex: 0x05070C), Color(hex: 0x0D1422)]
        case .ocean:
            return [Color(hex: 0x061A2B), Color(hex: 0x0A3147)]
        case .sunset:
            return [Color(hex: 0x2A0E1B), Color(hex: 0x3B1B0E)]
        case .graphite:
            return [Color(hex: 0x0C0D10), Color(hex: 0x1A1C22)]
        case .blossom:
            return [Color(hex: 0x241026), Color(hex: 0x3A1230)]
        }
    }
}

// MARK: - Менеджер темы

final class ThemeManager: ObservableObject {
    @Published var accent: AccentPalette {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }
    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var wallpaper: ChatWallpaper {
        didSet { defaults.set(wallpaper.rawValue, forKey: Keys.wallpaper) }
    }
    @Published var bubbleStyle: BubbleStyle {
        didSet { defaults.set(bubbleStyle.rawValue, forKey: Keys.bubbleStyle) }
    }
    @Published var fontScale: Double {
        didSet { defaults.set(fontScale, forKey: Keys.fontScale) }
    }
    @Published var largeEmoji: Bool {
        didSet { defaults.set(largeEmoji, forKey: Keys.largeEmoji) }
    }
    @Published var animations: Bool {
        didSet { defaults.set(animations, forKey: Keys.animations) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let accent = "theme.accent"
        static let appearance = "theme.appearance"
        static let wallpaper = "theme.wallpaper"
        static let bubbleStyle = "theme.bubbleStyle"
        static let fontScale = "theme.fontScale"
        static let largeEmoji = "theme.largeEmoji"
        static let animations = "theme.animations"
    }

    init() {
        accent = AccentPalette(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .neon
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .dark
        wallpaper = ChatWallpaper(rawValue: defaults.string(forKey: Keys.wallpaper) ?? "") ?? .aurora
        bubbleStyle = BubbleStyle(rawValue: defaults.string(forKey: Keys.bubbleStyle) ?? "") ?? .modern

        let storedScale = defaults.double(forKey: Keys.fontScale)
        fontScale = storedScale == 0 ? 1.0 : storedScale
        largeEmoji = defaults.object(forKey: Keys.largeEmoji) as? Bool ?? true
        animations = defaults.object(forKey: Keys.animations) as? Bool ?? true
    }

    // MARK: Фоны и текст

    var background: Color { Color.dynamic(dark: 0x0A0B0F, light: 0xF2F3F7) }
    var elevated: Color { Color.dynamic(dark: 0x12141A, light: 0xFFFFFF) }
    var card: Color { Color.dynamic(dark: 0x181B22, light: 0xFFFFFF) }
    var textPrimary: Color { Color.dynamic(dark: 0xF5F7FA, light: 0x0B0D12) }
    var textSecondary: Color { Color.dynamic(dark: 0x8B93A1, light: 0x6B7280) }
    var separator: Color { Color.dynamic(dark: 0x252A33, light: 0xE3E6EB) }
    var incomingBubble: Color { Color.dynamic(dark: 0x1C2028, light: 0xFFFFFF) }
    var field: Color { Color.dynamic(dark: 0x1A1E26, light: 0xEDEFF3) }

    var outgoingGradient: LinearGradient { accent.gradient }
    var outgoingText: Color { accent.onAccent }

    var bubbleCorner: CGFloat { bubbleStyle == .classic ? 14 : 20 }

    var textFont: Font { font(15) }
    var smallFont: Font { font(12) }
    var captionFont: Font { font(11) }

    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * CGFloat(fontScale), weight: weight)
    }

    func avatarColor(for title: String) -> Color {
        let scalars = title.unicodeScalars
        let sum = scalars.reduce(0) { $0 + Int($1.value) }
        let palette: [Color] = [
            Color(hex: 0x5B8DEF), Color(hex: 0x8E7CFF), Color(hex: 0xF2789B),
            Color(hex: 0xF5A25B), Color(hex: 0x38C9A0), Color(hex: 0xD96BF5),
            Color(hex: 0x42B8E0)
        ]
        return palette[abs(sum) % palette.count]
    }

    func avatarGradient(for title: String) -> LinearGradient {
        let base = avatarColor(for: title)
        return LinearGradient(
            colors: [base.opacity(0.95), base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

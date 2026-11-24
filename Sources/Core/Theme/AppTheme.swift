import SwiftUI
import UIKit
import Combine

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

    var rgb: [UInt32] {
        switch self {
        case .neon:
            return [0x66F5A0, 0x12B76A]
        case .ocean:
            return [0x4FACFE, 0x2A6BF2]
        case .violet:
            return [0xA78BFA, 0x6D28D9]
        case .sunset:
            return [0xFF8A65, 0xE0245E]
        case .amber:
            return [0xFFD166, 0xF59E0B]
        case .crimson:
            return [0xFF6B6B, 0xC81E5B]
        case .mint:
            return [0x7CF5D0, 0x0E9F8A]
        }
    }

    var tint: ThemeTint { ThemeTint(start: rgb[0], end: rgb[1]) }
}

// MARK: - Тема оформления

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
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

enum BubbleStyle: String, CaseIterable, Codable, Identifiable {
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

enum ChatWallpaper: String, CaseIterable, Codable, Identifiable {
    case aurora
    case midnight
    case ocean
    case sunset
    case graphite
    case blossom
    case pitch
    case plain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: return "Аврора"
        case .midnight: return "Полночь"
        case .ocean: return "Глубина"
        case .sunset: return "Тепло"
        case .graphite: return "Графит"
        case .blossom: return "Сакура"
        case .pitch: return "Чёрный"
        case .plain: return "Без градиента"
        }
    }

    var rgb: [UInt32] {
        switch self {
        case .aurora:
            return [0x17274E, 0x321957, 0x113D35]
        case .midnight:
            return [0x05070C, 0x0D1422]
        case .ocean:
            return [0x102236, 0x145471]
        case .sunset:
            return [0x59182D, 0x67321A]
        case .graphite:
            return [0x0C0D10, 0x292C34]
        case .blossom:
            return [0x281038, 0x581746]
        case .pitch, .plain:
            return [0x000000, 0x000000]
        }
    }
}

struct ThemeTint {
    let start: UInt32
    let end: UInt32
    var darkSurface: UInt32 = 0x121414
    var lightSurface: UInt32 = 0xFFFFFF

    var main: Color {
        .dynamic(dark: ThemeContrast.readable(start, on: darkSurface),
                 light: ThemeContrast.readable(start, on: lightSurface))
    }

    var secondary: Color { Color(hex: end) }

    private var ink: UInt32 { ThemeContrast.foreground(on: start) }
    var onAccent: Color { Color(hex: ink) }

    var gradient: LinearGradient {
        let safeEnd = ThemeContrast.readable(end, on: ink)
        let endpoint = (0...12).allSatisfy {
            ThemeContrast.ratio(ThemeContrast.mix(start, safeEnd, amount: Double($0) / 12), ink) >= 4.5
        } ? safeEnd : start
        return LinearGradient(colors: [Color(hex: start), Color(hex: endpoint)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

final class ThemeManager: ObservableObject {
    private struct State: Codable {
        var preset: ThemePreset
        var custom: ThemeProfile?
    }
    private static let storageKey = "whogram.design.v2"
    private let defaults: UserDefaults
    @Published private var state: State {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = State(preset: saved.preset, custom: saved.custom?.validated)
        } else if ["accent", "appearance", "wallpaper", "bubbleStyle", "fontScale", "largeEmoji", "animations"]
            .contains(where: { defaults.object(forKey: "theme.\($0)") != nil }) {
            var profile = ThemePreset.neonPulse.profile
            let colors = (AccentPalette(rawValue: defaults.string(forKey: "theme.accent") ?? "") ?? .neon).rgb
            profile.accentStart = colors[0]
            profile.accentEnd = colors[1]
            profile.appearance = AppearanceMode(rawValue: defaults.string(forKey: "theme.appearance") ?? "") ?? .dark
            profile.wallpaper = ChatWallpaper(rawValue: defaults.string(forKey: "theme.wallpaper") ?? "") ?? .aurora
            profile.bubble = BubbleStyle(rawValue: defaults.string(forKey: "theme.bubbleStyle") ?? "") ?? .modern
            profile.fontScale = defaults.object(forKey: "theme.fontScale") as? Double ?? 1
            profile.largeEmoji = defaults.object(forKey: "theme.largeEmoji") as? Bool ?? true
            profile.motion = defaults.object(forKey: "theme.animations") as? Bool ?? true
            profile.surface = .glass
            state = State(preset: .custom, custom: profile.validated)
            persist()
        } else {
            state = State(preset: .neonPulse, custom: nil)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }

    var preset: ThemePreset { state.preset }
    var profile: ThemeProfile { preset == .custom ? (state.custom ?? preset.profile) : preset.profile }

    func select(_ preset: ThemePreset) {
        guard preset != self.preset else { return }
        state = State(preset: preset, custom: state.custom ?? (preset == .custom ? profile : nil))
    }

    func edit(_ edit: (inout ThemeProfile) -> Void) {
        var profile = profile
        edit(&profile)
        state = State(preset: .custom, custom: profile.validated)
    }

    func resetCustom() {
        state = State(preset: .custom, custom: ThemePreset.neonPulse.profile)
    }

    var appearance: AppearanceMode { profile.appearance }
    var wallpaper: ChatWallpaper { profile.wallpaper }
    var bubbleStyle: BubbleStyle { profile.bubble }
    var fontScale: Double { profile.fontScale }
    var largeEmoji: Bool { profile.largeEmoji }
    var animations: Bool { profile.motion }
    var compact: Bool { profile.compact }
    var glow: Double { profile.glow }
    var radius: CGFloat { CGFloat(profile.radius) }
    var bubbleCorner: CGFloat { bubbleStyle == .classic ? min(14, radius) : radius }

    var accent: ThemeTint {
        ThemeTint(start: profile.accentStart, end: profile.accentEnd,
                  darkSurface: profile.darkSurface, lightSurface: profile.lightSurface)
    }

    private var outgoing: ThemeTint {
        ThemeTint(start: profile.outgoingStart ?? profile.accentStart, end: profile.outgoingEnd ?? profile.accentEnd)
    }
    var outgoingGradient: LinearGradient { outgoing.gradient }
    var outgoingText: Color { outgoing.onAccent }
    var background: Color { .dynamic(dark: profile.darkBackground, light: profile.lightBackground) }
    var card: Color { .dynamic(dark: profile.darkSurface, light: profile.lightSurface) }
    var elevated: Color { card }
    var textPrimary: Color {
        .dynamic(dark: ThemeContrast.foreground(on: profile.darkSurface), light: ThemeContrast.foreground(on: profile.lightSurface))
    }
    var textSecondary: Color {
        .dynamic(dark: ThemeContrast.readable(0xA5B0BC, on: profile.darkSurface),
                 light: ThemeContrast.readable(0x5C6570, on: profile.lightSurface))
    }
    var separator: Color { textPrimary.opacity(0.17) }
    var incomingBubble: Color { card }
    var field: Color {
        .dynamic(dark: ThemeContrast.mix(profile.darkSurface, ThemeContrast.foreground(on: profile.darkSurface), amount: 0.07),
                 light: ThemeContrast.mix(profile.lightSurface, ThemeContrast.foreground(on: profile.lightSurface), amount: 0.06))
    }

    var wallpaperColors: [Color] {
        if wallpaper == .plain { return [background, background] }
        return wallpaper.rgb.map {
            .dynamic(dark: ThemeContrast.mix(profile.darkBackground, $0, amount: profile.wallpaperStrength),
                     light: ThemeContrast.mix(profile.lightBackground, $0, amount: profile.wallpaperStrength * 0.15))
        }
    }

    func animation(_ animation: Animation, reduced: Bool) -> Animation? {
        animations && !reduced ? animation : nil
    }

    var textFont: Font { font(15) }
    var smallFont: Font { font(12) }
    var captionFont: Font { font(11) }

    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let design: Font.Design
        switch profile.typeface {
        case .system: design = .default
        case .rounded: design = .rounded
        case .monospaced: design = .monospaced
        }
        return .system(size: UIFontMetrics.default.scaledValue(for: size * CGFloat(fontScale)), weight: weight, design: design)
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

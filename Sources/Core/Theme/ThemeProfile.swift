import Foundation

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: return "Тёмная"
        case .light: return "Светлая"
        case .system: return "Системная"
        }
    }
}

enum BubbleStyle: String, CaseIterable, Codable, Identifiable {
    case modern, glass, classic
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
    case aurora, midnight, ocean, sunset, graphite, blossom, pitch, plain
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
        case .aurora: return [0x17274E, 0x321957, 0x113D35]
        case .midnight: return [0x05070C, 0x0D1422]
        case .ocean: return [0x102236, 0x145471]
        case .sunset: return [0x59182D, 0x67321A]
        case .graphite: return [0x0C0D10, 0x292C34]
        case .blossom: return [0x281038, 0x581746]
        case .pitch, .plain: return [0, 0]
        }
    }
}

struct ThemeSelection: Codable, Equatable {
    var preset: ThemePreset
    var custom: ThemeProfile?
    var saved: [SavedTheme]?

    var active: ThemeProfile {
        preset == .custom ? (custom ?? ThemePreset.neonPulse.profile) : preset.profile
    }

    mutating func select(_ preset: ThemePreset) {
        if preset == .custom && custom == nil { custom = active }
        self.preset = preset
    }

    mutating func copyToCustom() {
        custom = active
        preset = .custom
    }

    mutating func editCustom(_ change: (inout ThemeProfile) -> Void) {
        guard preset == .custom else { return }
        var changed = active
        change(&changed)
        custom = changed.validated
    }

    mutating func save(_ name: String, replacing id: UUID? = nil) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else { return }
        if let id, let index = saved?.firstIndex(where: { $0.id == id }) {
            saved?[index].name = trimmed
        } else if id == nil && (saved?.count ?? 0) < 24 {
            var snapshot = active
            snapshot.usesLocalPhoto = nil
            saved = (saved ?? []) + [SavedTheme(id: UUID(), name: trimmed, profile: snapshot)]
        }
    }

    mutating func applySaved(_ id: UUID) {
        guard let saved = saved?.first(where: { $0.id == id }) else { return }
        custom = saved.profile.validated
        preset = .custom
    }

    mutating func deleteSaved(_ id: UUID) {
        saved?.removeAll { $0.id == id }
    }
}

struct SavedTheme: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let profile: ThemeProfile
}

enum ChatDensity: String, Codable, CaseIterable, Identifiable {
    case compact, standard, spacious
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: return "Компактно"
        case .standard: return "Стандартно"
        case .spacious: return "Просторно"
        }
    }
    var avatar: Double { self == .compact ? 42 : (self == .standard ? 53 : 62) }
    var padding: Double { self == .compact ? 5 : (self == .standard ? 8 : 11) }
}

enum ThemePreset: String, CaseIterable, Codable, Identifiable {
    case neonPulse, liquidGlass, oled, aurora, cyberpunk, minimal, telegram, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neonPulse: return "Neon Pulse"
        case .liquidGlass: return "Liquid Glass"
        case .oled: return "OLED Ultra Dark"
        case .aurora: return "Aurora"
        case .cyberpunk: return "Cyberpunk"
        case .minimal: return "Minimal"
        case .telegram: return "Telegram Classic"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .neonPulse: return "bolt.fill"
        case .liquidGlass: return "drop"
        case .oled: return "moon.stars.fill"
        case .aurora: return "waveform.path"
        case .cyberpunk: return "cpu"
        case .minimal: return "circle.lefthalf.filled"
        case .telegram: return "paperplane.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var profile: ThemeProfile {
        switch self {
        case .neonPulse, .custom:
            return .init(0x020503, 0x101711, 0xF1F6EF, 0xFFFFFF, 0xC1FF37, 0x79EE27,
                         appearance: .dark, wallpaper: .pitch, surface: .neon, radius: 22, glow: 0.24)
        case .liquidGlass:
            return .init(0x131B31, 0x24334D, 0xE8F2FE, 0xFFFFFF, 0xAAE8FF, 0xA9BAFF,
                         appearance: .system, wallpaper: .ocean, bubble: .glass, surface: .glass, radius: 25, glow: 0.12)
        case .oled:
            return .init(0x000000, 0x101010, 0xFFFFFF, 0xF2F2F2, 0xEEEEEE, 0xCCCCCC,
                         appearance: .dark, wallpaper: .pitch, surface: .flat, radius: 14, glow: 0, motion: false, compact: true)
        case .aurora:
            return .init(0x0B1127, 0x1B2240, 0xEEEDFA, 0xFBF9FF, 0xBCA6FF, 0x70E3CE,
                         appearance: .dark, wallpaper: .aurora, bubble: .glass, surface: .glass, radius: 24, glow: 0.23)
        case .cyberpunk:
            return .init(0x100518, 0x22112E, 0xFBEAF6, 0xFFF8FC, 0xFF7ED3, 0xB583FF,
                         appearance: .dark, wallpaper: .blossom, surface: .neon, radius: 12, glow: 0.26)
        case .minimal:
            return .init(0x181919, 0x232424, 0xF6F6F3, 0xFFFFFF, 0xB9C9D3, 0xA1B4C3,
                         appearance: .system, wallpaper: .plain, bubble: .classic, surface: .flat, radius: 12, glow: 0, motion: false)
        case .telegram:
            return .init(0x17212B, 0x202B36, 0xE8EFF5, 0xFFFFFF, 0x86D1FF, 0x57B7F1,
                         appearance: .system, wallpaper: .ocean, bubble: .classic, surface: .flat, radius: 14, glow: 0)
        }
    }
}

enum SurfaceStyle: String, CaseIterable, Codable, Identifiable {
    case neon, glass, flat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .neon: return "Неон"
        case .glass: return "Стекло"
        case .flat: return "Матовый"
        }
    }
}

enum ThemeTypeface: String, CaseIterable, Codable, Identifiable {
    case system, rounded, monospaced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Системный"
        case .rounded: return "Скруглённый"
        case .monospaced: return "Моноширинный"
        }
    }
}

struct ThemeProfile: Codable, Equatable {
    var darkBackground: UInt32
    var darkSurface: UInt32
    var lightBackground: UInt32
    var lightSurface: UInt32
    var accentStart: UInt32
    var accentEnd: UInt32
    var appearance: AppearanceMode
    var wallpaper: ChatWallpaper
    var bubble: BubbleStyle
    var surface: SurfaceStyle
    var radius: Double
    var glow: Double
    var motion: Bool
    var compact: Bool
    var typeface: ThemeTypeface = .system
    var fontScale: Double = 1
    var largeEmoji: Bool = true
    var wallpaperStrength: Double = 1
    var usesLocalPhoto: Bool?
    var outgoingStart: UInt32?
    var outgoingEnd: UInt32?
    var incomingColor: UInt32?
    var messageRadius: Double?
    var chatDensity: ChatDensity?
    var avatarScale: Double?
    var showsChatPreview: Bool?
    var showsChatTime: Bool?
    var showsChatDividers: Bool?
    var outlinedBubbles: Bool?
    var composerRadius: Double?
    var composerScale: Double?
    var animationSpeed: Double?

    init(
        _ darkBackground: UInt32, _ darkSurface: UInt32, _ lightBackground: UInt32,
        _ lightSurface: UInt32, _ accentStart: UInt32, _ accentEnd: UInt32,
        appearance: AppearanceMode, wallpaper: ChatWallpaper, bubble: BubbleStyle = .modern,
        surface: SurfaceStyle, radius: Double, glow: Double, motion: Bool = true, compact: Bool = false
    ) {
        self.darkBackground = darkBackground
        self.darkSurface = darkSurface
        self.lightBackground = lightBackground
        self.lightSurface = lightSurface
        self.accentStart = accentStart
        self.accentEnd = accentEnd
        self.appearance = appearance
        self.wallpaper = wallpaper
        self.bubble = bubble
        self.surface = surface
        self.radius = radius
        self.glow = glow
        self.motion = motion
        self.compact = compact
    }

    var validated: Self {
        var result = self
        result.radius = Self.clamp(radius, to: 8...32, fallback: 22)
        result.glow = Self.clamp(glow, to: 0...0.4, fallback: 0)
        result.fontScale = Self.clamp(fontScale, to: 0.85...1.3, fallback: 1)
        result.wallpaperStrength = Self.clamp(wallpaperStrength, to: 0...1, fallback: 1)
        result.messageRadius = messageRadius.map { Self.clamp($0, to: 8...32, fallback: 16) }
        result.avatarScale = avatarScale.map { Self.clamp($0, to: 0.8...1.2, fallback: 1) }
        result.composerRadius = composerRadius.map { Self.clamp($0, to: 8...28, fallback: 18) }
        result.composerScale = composerScale.map { Self.clamp($0, to: 1...1.3, fallback: 1) }
        result.animationSpeed = animationSpeed.map { Self.clamp($0, to: 0.5...1.5, fallback: 1) }
        return result
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}

enum ThemeContrast {
    static func parseHex(_ input: String) -> UInt32? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard digits.utf8.count == 6,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { return nil }
        return UInt32(digits, radix: 16)
    }

    static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ shift: UInt32) -> Double {
            let value = Double((rgb >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }

    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func foreground(on background: UInt32) -> UInt32 {
        ratio(0, background) >= ratio(0xFFFFFF, background) ? 0 : 0xFFFFFF
    }

    static func mix(_ first: UInt32, _ second: UInt32, amount: Double) -> UInt32 {
        [UInt32(16), 8, 0].reduce(0) { result, shift in
            let a = Double((first >> shift) & 255)
            let b = Double((second >> shift) & 255)
            return result | (UInt32((a + (b - a) * amount).rounded()) << shift)
        }
    }

    static func readable(_ color: UInt32, on background: UInt32) -> UInt32 {
        if ratio(color, background) >= 4.5 { return color }
        let target = foreground(on: background)
        for step in 1...20 {
            let candidate = mix(color, target, amount: Double(step) / 20)
            if ratio(candidate, background) >= 4.5 { return candidate }
        }
        return target
    }
}

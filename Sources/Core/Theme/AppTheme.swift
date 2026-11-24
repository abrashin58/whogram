import SwiftUI
import UIKit
import Combine
import ImageIO

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

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
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
    private static let storageKey = "whogram.design.v2"
    private let defaults: UserDefaults
    @Published private var state: ThemeSelection {
        didSet { persist() }
    }
    @Published private(set) var wallpaperImage: UIImage?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(ThemeSelection.self, from: data) {
            state = ThemeSelection(preset: saved.preset, custom: saved.custom?.validated, saved: saved.saved)
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
            state = ThemeSelection(preset: .custom, custom: profile.validated)
            persist()
        } else {
            state = ThemeSelection(preset: .firstLaunch, custom: nil)
        }
        if let url = Self.wallpaperURL {
            wallpaperImage = UIImage(contentsOfFile: url.path)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }

    var preset: ThemePreset { state.preset }
    var profile: ThemeProfile { state.active }
    var customProfile: ThemeProfile? { state.custom }
    var savedThemes: [SavedTheme] { state.saved ?? [] }

    func select(_ preset: ThemePreset) {
        guard preset != self.preset else { return }
        state.select(preset)
    }

    func edit(_ edit: (inout ThemeProfile) -> Void) {
        guard preset == .custom else { return }
        state.editCustom(edit)
    }

    func copyToCustom() {
        state.copyToCustom()
    }

    func resetCustom() {
        state = ThemeSelection(preset: .custom, custom: ThemePreset.neonPulse.profile, saved: state.saved)
    }

    func saveTheme(_ name: String, replacing id: UUID? = nil) { state.save(name, replacing: id) }
    func applyTheme(_ id: UUID) { state.applySaved(id) }
    func deleteTheme(_ id: UUID) { state.deleteSaved(id) }

    private static var wallpaperURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("WhogramDesign", isDirectory: true)
            .appendingPathComponent("wallpaper.jpg")
    }

    func saveWallpaper(_ data: Data) throws {
        guard preset == .custom, let url = Self.wallpaperURL,
              let image = UIImage(data: data) else { throw WallpaperError.invalidImage }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        wallpaperImage = image
        edit { $0.usesLocalPhoto = true }
    }

    func removeWallpaper() throws {
        if let url = Self.wallpaperURL, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        wallpaperImage = nil
        edit { $0.usesLocalPhoto = nil }
    }

    static func wallpaperJPEG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.82)
    }

    enum WallpaperError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "Не удалось открыть выбранную фотографию." }
    }

    var appearance: AppearanceMode { profile.appearance }
    var wallpaper: ChatWallpaper { profile.wallpaper }
    var bubbleStyle: BubbleStyle { profile.bubble }
    var fontScale: Double { profile.fontScale }
    var largeEmoji: Bool { profile.largeEmoji }
    var animations: Bool { profile.motion }
    var chatDensity: ChatDensity { profile.chatDensity ?? (profile.compact ? .compact : .standard) }
    var compact: Bool { chatDensity == .compact }
    var chatAvatar: CGFloat { CGFloat(chatDensity.avatar * (profile.avatarScale ?? 1)) }
    var composerRadius: CGFloat { CGFloat(profile.composerRadius ?? profile.radius) }
    var composerControl: CGFloat { 44 * CGFloat(profile.composerScale ?? 1) }
    var glow: Double { profile.glow }
    var radius: CGFloat { CGFloat(profile.radius) }
    var bubbleCorner: CGFloat { profile.messageRadius.map { CGFloat($0) } ?? (bubbleStyle == .classic ? min(14, radius) : radius) }

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
    var incomingBubble: Color { profile.incomingColor.map { Color(hex: $0) } ?? card }
    var incomingText: Color { profile.incomingColor.map { Color(hex: ThemeContrast.foreground(on: $0)) } ?? textPrimary }
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
        animations && !reduced ? animation.speed(profile.animationSpeed ?? 1) : nil
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

import Foundation

@main
struct CoreChecks {
    static func main() throws {
        checkVoiceWaveform()
        try checkThemes()
        print("OK: пресеты, Custom, сохранение, контраст, кодирование голосовой дорожки")
    }

    static func checkVoiceWaveform() {
        let bytes = VoiceWaveform.pack([1, 2, 3, 4, 5, 6, 7, 8])
        precondition(Array(bytes) == [0x41, 0x0C, 0x52, 0xCC, 0x41])
        let samples: [UInt8] = (0..<64).map { UInt8(($0 * 19) % 32) }
        precondition(VoiceWaveform.pack(samples).count == 40)
        precondition(VoiceWaveform.unpack(VoiceWaveform.pack(samples)) == samples)
        precondition(VoiceWaveform.pack([]).isEmpty)
        precondition(VoiceWaveform.unpack(Data()).isEmpty)
        precondition(VoiceWaveform.resample([1, 12, 3, 5, 7, 10], count: 2) == [12, 10])
        precondition(VoiceWaveform.resample([5], count: 5) == [5, 5, 5, 5, 5])
    }

    static func checkThemes() throws {
        let presets = ThemePreset.allCases.filter { $0 != .custom }.map(\.profile)
        precondition(presets.count == 7)
        precondition(Set(presets.map(\.darkBackground)).count == 7)
        precondition(ThemePreset.oled.profile.darkBackground == 0)
        precondition(!ThemePreset.oled.profile.motion && !ThemePreset.minimal.profile.motion)
        precondition(ThemePreset.liquidGlass.profile.surface == .glass)

        var selection = ThemeSelection(preset: .aurora)
        selection.editCustom { $0.fontScale = 1.2 }
        precondition(selection.active == ThemePreset.aurora.profile && selection.custom == nil)
        selection.copyToCustom()
        precondition(selection.active == ThemePreset.aurora.profile)
        selection.editCustom {
            $0.radius = 100
            $0.glow = -4
            $0.fontScale = 1.15
            $0.wallpaperStrength = .nan
            $0.usesLocalPhoto = true
            $0.outgoingStart = 0xAB12FE
        }
        let custom = selection.active
        precondition(custom.radius == 32 && custom.glow == 0 && custom.wallpaperStrength == 1)
        selection.select(.cyberpunk)
        precondition(selection.active == ThemePreset.cyberpunk.profile)
        selection.select(.custom)
        precondition(selection.active == custom)
        let encoded = try JSONEncoder().encode(selection)
        let restored = try JSONDecoder().decode(ThemeSelection.self, from: encoded)
        precondition(restored == selection)

        for base: UInt32 in [0, 0xFFFFFF, 0x858585, 0xFF0088, 0x152033] {
            let ink = ThemeContrast.foreground(on: base)
            precondition(ThemeContrast.ratio(ink, base) >= 4.5)
            precondition(ThemeContrast.ratio(ThemeContrast.readable(0xA5B0BC, on: base), base) >= 4.5)
        }
    }
}

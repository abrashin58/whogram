import Foundation

@main
struct CoreChecks {
    static func main() throws {
        checkVoiceWaveform()
        try checkThemes()
        try checkSessionFolders()
        checkHistory()
        print("OK: темы, HEX, хранилище сессии, курсор истории, звуковая волна")
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
        selection.save("  Тест  ")
        let saved = selection.saved!.first!
        precondition(saved.name == "Тест" && saved.profile.usesLocalPhoto == nil)
        selection.save("Новое название", replacing: saved.id)
        selection.editCustom { $0.fontScale = 0.9 }
        selection.applySaved(saved.id)
        precondition(selection.active.fontScale == custom.fontScale)
        precondition(selection.saved?.first?.name == "Новое название")
        let serialized = try JSONEncoder().encode(selection)
        let roundTrip = try JSONDecoder().decode(ThemeSelection.self, from: serialized)
        precondition(roundTrip == selection)
        selection.deleteSaved(saved.id)
        precondition(selection.saved?.isEmpty == true)
        let legacy = try JSONDecoder().decode(ThemeSelection.self, from: Data(#"{"preset":"aurora"}"#.utf8))
        precondition(legacy.preset == .aurora && legacy.saved == nil)
        precondition(ThemeContrast.parseHex(" #af00BA ") == 0xAF00BA)
        precondition(ThemeContrast.parseHex("GG0000") == nil && ThemeContrast.parseHex("123") == nil)

        for base: UInt32 in [0, 0xFFFFFF, 0x858585, 0xFF0088, 0x152033] {
            let ink = ThemeContrast.foreground(on: base)
            precondition(ThemeContrast.ratio(ink, base) >= 4.5)
            precondition(ThemeContrast.ratio(ThemeContrast.readable(0xA5B0BC, on: base), base) >= 4.5)
        }
    }

    static func checkSessionFolders() throws {
        let fm = FileManager.default
        let documents = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: documents) }
        let first = try SessionFolders.prepare(documents: documents)
        let marker = first.database.appendingPathComponent("existing")
        let data = Data([7, 18])
        try data.write(to: marker)
        let second = try SessionFolders.prepare(documents: documents)
        precondition(first.database == second.database && first.files == second.files)
        precondition(second.database.path.hasSuffix("/Whogram/Database") && second.files.path.hasSuffix("/Whogram/Files"))
        let persisted = try Data(contentsOf: marker)
        precondition(persisted == data)
        do {
            _ = try SessionFolders.prepare(documents: marker)
            preconditionFailure("Ожидалась ошибка создания каталога")
        } catch {
            precondition(fm.fileExists(atPath: marker.path))
        }
    }

    static func checkHistory() {
        precondition(HistoryPage.progress(ids: [90, 82, 82, -8, 70], from: 0) == .older(70))
        precondition(HistoryPage.progress(ids: [71, 70, 60], from: 70) == .older(60))
        precondition(HistoryPage.progress(ids: [71, 70], from: 70) == .end)
        precondition(HistoryPage.progress(ids: [], from: 0) == .end)
    }
}

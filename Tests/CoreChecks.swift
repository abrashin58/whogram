import Foundation

@main
struct CoreChecks {
    static func main() throws {
        checkVoiceWaveform()
        try checkThemes()
        try checkSessionFolders()
        try checkSessionSafety()
        checkHistory()
        print("OK: темы, HEX, изоляция сессии, разрешения TDLib, курсор истории, звуковая волна")
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
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let legacy = root.appendingPathComponent("Documents/Whogram/Database", isDirectory: true)
        try fm.createDirectory(at: legacy, withIntermediateDirectories: true)
        let legacyMarker = legacy.appendingPathComponent("td.binlog")
        let legacyData = Data([99])
        try legacyData.write(to: legacyMarker)
        let support = root.appendingPathComponent("Application Support", isDirectory: true)
        let storageID = UUID()
        let first = try SessionFolders.prepare(storageID: storageID, applicationSupport: support)
        let marker = first.database.appendingPathComponent("existing")
        let data = Data([7, 18])
        try data.write(to: marker)
        let second = try SessionFolders.prepare(storageID: storageID, applicationSupport: support)
        precondition(first.database == second.database && first.files == second.files)
        precondition(second.database.path.hasSuffix("/WhogramSessions/\(storageID.uuidString)/Database"))
        let different = try SessionFolders.prepare(storageID: UUID(), applicationSupport: support)
        precondition(different.database != second.database)
        let persisted = try Data(contentsOf: marker)
        precondition(persisted == data)
        let legacyPersisted = try Data(contentsOf: legacyMarker)
        precondition(legacyPersisted == legacyData)
        precondition(!fm.fileExists(atPath: first.database.appendingPathComponent("td.binlog").path))
        do {
            _ = try SessionFolders.prepare(storageID: storageID, applicationSupport: marker)
            preconditionFailure("Ожидалась ошибка создания каталога")
        } catch {
            precondition(fm.fileExists(atPath: marker.path))
        }
    }

    static func checkSessionSafety() throws {
        let hash = String(repeating: "AB", count: 16)
        precondition((try? TelegramAppIdentity(id: "", hash: hash)) == nil)
        precondition((try? TelegramAppIdentity(id: "2086616", hash: hash)) == nil)
        precondition((try? TelegramAppIdentity(id: "93451234", hash: "abcd")) == nil)
        let configured = try TelegramAppIdentity(id: " 93451234 ", hash: hash)
        let roundTrip = try JSONDecoder().decode(TelegramAppIdentity.self, from: JSONEncoder().encode(configured))
        precondition(configured == roundTrip && roundTrip.apiHash == hash.lowercased())
        var gate = SessionStartupGate()
        precondition(gate.needsApproval && !gate.approve(hasIdentity: false))
        precondition(gate.approve(hasIdentity: true) && !gate.approve(hasIdentity: true))
        gate.didClose()
        precondition(gate.needsApproval)

        for method in ["terminateSession", "terminateAllOtherSessions", "terminateAllWebAppSessions",
                       "deleteAccount", "destroy", "setInactiveSessionTtl"] {
            for scope in [SessionRequestPolicy.Scope.ordinary, .bootstrap, .authentication, .confirmedLocalLogout, .disconnect] {
                precondition(!SessionRequestPolicy.allows(method, scope: scope))
            }
        }
        precondition(SessionRequestPolicy.allows("logOut", scope: .confirmedLocalLogout))
        precondition(!SessionRequestPolicy.allows("logOut", scope: .ordinary))
        precondition(SessionRequestPolicy.allows("close", scope: .disconnect))
        precondition(!SessionRequestPolicy.allows("close", scope: .ordinary))
        precondition(SessionRequestPolicy.allows("getMe", scope: .ordinary))
        precondition(SessionRequestPolicy.allows("setTdlibParameters", scope: .bootstrap))
        precondition(!SessionRequestPolicy.allows("setTdlibParameters", scope: .ordinary))
        precondition(SessionRequestPolicy.allows("checkAuthenticationCode", scope: .authentication))
        precondition(!SessionRequestPolicy.allows("checkAuthenticationCode", scope: .ordinary))
        precondition(SessionRequestPolicy.securityCode(in: "401: SESSION_REVOKED") == "SESSION_REVOKED")
        precondition(SessionRequestPolicy.securityCode(in: "CONNECTION_API_ID_INVALID") == "CONNECTION_API_ID_INVALID")
        precondition(SessionRequestPolicy.securityCode(in: "unrecognized 123456") == nil)
    }

    static func checkHistory() {
        precondition(HistoryPage.progress(ids: [90, 82, 82, -8, 70], from: 0) == .older(70))
        precondition(HistoryPage.progress(ids: [71, 70, 60], from: 70) == .older(60))
        precondition(HistoryPage.progress(ids: [71, 70], from: 70) == .end)
        precondition(HistoryPage.progress(ids: [], from: 0) == .end)
    }
}

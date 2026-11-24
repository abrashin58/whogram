import Foundation

@main
struct CoreChecks {
    static func main() throws {
        checkVoiceWaveform()
        try checkThemes()
        try checkSessionFolders()
        try checkSessionSafety()
        try checkAccountCatalog()
        checkAuthorizationLifecycle()
        checkAuthJournal()
        checkChatOrder()
        checkHistory()
        print("OK: AuthLifecycle, AuthJournal, хранилище сессий, темы, история, звуковая волна")
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
        precondition(presets.count == 8)
        precondition(Set(presets.map(\.darkBackground)).count == 8)
        let firstLaunch = ThemePreset.firstLaunch.profile
        precondition(firstLaunch.appearance == .light && firstLaunch.lightBackground == 0xFFFFFF)
        precondition(firstLaunch.wallpaper == .plain && firstLaunch.surface == .flat)
        precondition(firstLaunch.outgoingStart == 0xD5EEFF && firstLaunch.incomingColor != firstLaunch.lightBackground)
        precondition(ThemePreset.telegram.profile.appearance == .system)
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
        let marker = first.database.appendingPathComponent("td.binlog")
        let data = Data([7, 18])
        try data.write(to: marker)
        let second = try SessionFolders.prepare(storageID: storageID, requiresExistingDatabase: true, applicationSupport: support)
        precondition(first.database == second.database && first.files == second.files)
        precondition(second.database.path.hasSuffix("/WhogramSessions/\(storageID.uuidString)/Database"))
        let different = try SessionFolders.prepare(storageID: UUID(), applicationSupport: support)
        precondition(different.database != second.database)
        let persisted = try Data(contentsOf: marker)
        precondition(persisted == data)
        let legacyPersisted = try Data(contentsOf: legacyMarker)
        precondition(legacyPersisted == legacyData)
        let docs = root.appendingPathComponent("Documents", isDirectory: true)
        precondition(SessionFolders.hasLegacyDatabase(documents: docs))
        let adopted = try SessionFolders.legacyFolders(documents: docs)
        precondition(adopted.database.path == legacy.path && adopted.database != second.database)
        let reopenedLegacy = try Data(contentsOf: adopted.database.appendingPathComponent("td.binlog"))
        precondition(reopenedLegacy == legacyData)
        precondition(SessionFolders.hasDatabase(storageID: storageID, applicationSupport: support))
        precondition(!SessionFolders.hasDatabase(storageID: UUID(), applicationSupport: support))
        let missingID = UUID()
        let emptyID = UUID()
        let empty = try SessionFolders.prepare(storageID: emptyID, applicationSupport: support)
        let unrelated = empty.database.appendingPathComponent("unrelated")
        try data.write(to: unrelated)
        precondition((try? SessionFolders.prepare(storageID: emptyID, requiresExistingDatabase: true,
                                                  applicationSupport: support)) == nil)
        try Data().write(to: empty.database.appendingPathComponent("td.binlog"))
        precondition(!SessionFolders.hasDatabase(storageID: emptyID, applicationSupport: support))
        do {
            _ = try SessionFolders.prepare(storageID: missingID, requiresExistingDatabase: true, applicationSupport: support)
            preconditionFailure("Пропавшая база не должна создаваться заново")
        } catch SessionCatalogError.missingDatabase {
            precondition(!fm.fileExists(atPath: support.appendingPathComponent("WhogramSessions/\(missingID.uuidString)").path))
        }
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
        precondition((try? TelegramAppIdentity(id: "93451234", hash: "abcd")) == nil)
        let configured = try TelegramAppIdentity(id: " 93451234 ", hash: " \(hash)\n")
        let roundTrip = try JSONDecoder().decode(TelegramAppIdentity.self, from: JSONEncoder().encode(configured))
        precondition(configured == roundTrip && roundTrip.apiHash == hash)
        precondition(configured.apiID == 93451234)
        let a = UUID(), b = UUID()
        var budget = SessionRecoveryBudget()
        precondition(budget.consume(for: a, at: 100))
        precondition(!budget.consume(for: a, at: 110))
        precondition(budget.consume(for: b, at: 110))
        precondition(budget.consume(for: a, at: 161))
        precondition(SessionClosePolicy.action(intent: nil, loggedOut: false, hadSecurityStop: false, canRecover: true) == .recover)
        precondition(SessionClosePolicy.action(intent: nil, loggedOut: false, hadSecurityStop: true, canRecover: true) == .pause)
        precondition(SessionClosePolicy.action(intent: nil, loggedOut: true, hadSecurityStop: false, canRecover: true) == .chooseAccount)
        precondition(SessionClosePolicy.action(intent: .chooseAccount, loggedOut: false, hadSecurityStop: false, canRecover: true) == .chooseAccount)
        precondition(SessionClosePolicy.action(intent: .switchAccount(b), loggedOut: false, hadSecurityStop: false, canRecover: false) == .switchAccount(b))
        precondition(SessionClosePolicy.action(intent: .switchAccount(b), loggedOut: false, hadSecurityStop: true, canRecover: true) == .pause)

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
        precondition(SessionRequestPolicy.matchesAuthState("checkAuthenticationCode", state: "authorizationStateWaitCode"))
        precondition(!SessionRequestPolicy.matchesAuthState("checkAuthenticationCode", state: "authorizationStateWaitPassword"))
        precondition(SessionRequestPolicy.securityCode(in: "401: SESSION_REVOKED") == "SESSION_REVOKED")
        precondition(SessionRequestPolicy.securityCode(in: "CONNECTION_API_ID_INVALID") == "CONNECTION_API_ID_INVALID")
        precondition(SessionRequestPolicy.securityCode(in: "unrecognized 123456") == nil)
    }

    static func checkAccountCatalog() throws {
        let id = "93451234"
        let syntheticHash = String(repeating: "a", count: 32)
        let first = try TelegramAppIdentity(id: id, hash: syntheticHash)
        let second = try TelegramAppIdentity(id: id, hash: syntheticHash)
        var catalog = SessionCatalog(legacyIdentity: first)
        precondition(catalog.selectedID == first.storageID && catalog.profiles[0].databaseKey == nil)
        precondition(catalog.profiles[0].canResumeAtLaunch(hasLegacyDatabase: true))
        precondition(!catalog.profiles[0].canResumeAtLaunch())
        catalog.confirmAuthorization(for: first.storageID, title: "First")
        let secondKey = Data(repeating: 8, count: 32)
        catalog.add(second, databaseKey: secondKey)
        precondition(catalog.selectedID == second.storageID && first.storageID != second.storageID)
        catalog.add(second, databaseKey: secondKey)
        precondition(catalog.profiles.count == 2)
        catalog.confirmAuthorization(for: second.storageID)
        catalog.confirmLocalLogout(for: second.storageID)
        precondition(catalog.profile(first.storageID)?.wasAuthorized == true)
        precondition(catalog.profile(second.storageID)?.wasAuthorized == false)
        catalog.select(first.storageID)
        catalog.select(UUID())
        let decoded = try JSONDecoder().decode(SessionCatalog.self, from: JSONEncoder().encode(catalog)).validated()
        precondition(decoded == catalog && decoded.selectedID == first.storageID)
        precondition(decoded.profile(second.storageID)?.databaseKey == secondKey)
        precondition(decoded.profile(first.storageID)?.canResumeAtLaunch() == true)
        precondition(decoded.profile(second.storageID)?.canResumeAtLaunch() == false)
        try catalog.updateIdentity(for: second.storageID, id: "93451235", hash: syntheticHash)
        precondition(catalog.selectedID == second.storageID && catalog.profile(second.storageID)?.databaseKey == secondKey)
        precondition(catalog.profile(second.storageID)?.identity.apiID == 93451235)
        precondition(catalog.profile(first.storageID)?.identity == first)
        catalog.suspendAutomaticRecovery(for: first.storageID)
        let paused = try JSONDecoder().decode(SessionCatalog.self, from: JSONEncoder().encode(catalog)).validated()
        precondition(paused.profile(first.storageID)?.canResumeAtLaunch(hasLegacyDatabase: true) == false)
        precondition(paused.profile(first.storageID)?.wasAuthorized == true)
        catalog.confirmAuthorization(for: first.storageID)
        precondition(catalog.profile(first.storageID)?.canResumeAtLaunch() == true)
        let legacy = try TelegramAppIdentity(id: "93451235", hash: syntheticHash)
        catalog.adoptLegacy(legacy)
        catalog.adoptLegacy(try TelegramAppIdentity(id: "93451236", hash: syntheticHash))
        let adopted = try catalog.validated()
        precondition(adopted.profiles.filter { $0.usesLegacyFolders == true }.count == 1)
        precondition(adopted.profile(legacy.storageID)?.databaseKey == nil)
        precondition(adopted.profile(legacy.storageID)?.canResumeAtLaunch(hasLegacyDatabase: true) == false)
        let corrupt = try JSONDecoder().decode(SessionCatalog.self, from: Data(#"{"profiles":[],"selectedID":"00000000-0000-0000-0000-000000000000"}"#.utf8))
        precondition((try? corrupt.validated()) == nil)
    }

    static func checkAuthorizationLifecycle() {
        var flow = AuthLifecycle()
        precondition(flow.phase == .idle && flow.begin(.bootstrap) == nil)
        flow.startClient()
        precondition(flow.begin(.bootstrap) == nil)
        precondition(flow.observe(.parameters) == .advanced)
        let bootstrap = flow.begin(.bootstrap)!
        precondition(flow.reply(to: bootstrap, ok: true) == .waitingForUpdate)
        precondition(flow.observe(.parameters) == .refreshed && flow.begin(.bootstrap) == nil)
        precondition(flow.expire(bootstrap) && !flow.expire(bootstrap))
        precondition(flow.begin(.bootstrap) == nil)
        precondition(flow.observe(.phone) == .advanced && !flow.timedOut)
        let phone = flow.begin(.phone)!
        precondition(flow.begin(.qr) == nil)
        precondition(flow.reply(to: phone, ok: false) == .finished)
        let retry = flow.begin(.phone)!
        precondition(flow.observe(.code) == .advanced)
        precondition(flow.reply(to: retry, ok: true) == .stale)
        let resend = flow.begin(.resend)!
        precondition(flow.observe(.code) == .refreshed && flow.begin(.code) == nil)
        precondition(flow.reply(to: resend, ok: true) == .finished)
        let code = flow.begin(.code)!
        precondition(flow.observe(.password) == .advanced)
        precondition(flow.reply(to: code, ok: true) == .stale)
        let password = flow.begin(.password)!
        precondition(flow.reply(to: password, ok: true) == .waitingForUpdate)
        precondition(flow.observe(.ready) == .advanced)
        precondition(flow.observe(.ready) == .refreshed)
        precondition(flow.observe(.phone) == .rejected)
        precondition(flow.observe(.closing) == .advanced)
        precondition(flow.observe(.ready) == .rejected)
        precondition(flow.observe(.closed) == .advanced)
        precondition(flow.observe(.parameters) == .rejected)
        flow.startClient()
        precondition(flow.observe(.parameters) == .advanced)
        let reopen = flow.begin(.bootstrap)!
        precondition(flow.reply(to: bootstrap, ok: true) == .stale)
        precondition(flow.observe(.ready) == .advanced && flow.reply(to: reopen, ok: true) == .stale)
        precondition(AuthMethod.register.allowed(in: .registration) && !AuthMethod.register.allowed(in: .code))
        precondition(AuthMethod.resend.allowed(in: .emailCode))
        precondition(AuthPhase(update: "authorizationStateUnrecognized") == .unsupported)
    }

    static func checkAuthJournal() {
        let suite = "whogram.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var journal = AuthJournal(defaults: defaults)
        let date = Date(timeIntervalSince1970: 0)
        journal.append(.response(.password, 400, "private-field-must-not-leak"), at: date)
        journal.append(.response(.code, 400, "PHONE_CODE_INVALID"), at: date)
        let loaded = AuthJournal(defaults: defaults)
        precondition(loaded.entries.count == 2)
        precondition(loaded.entries[0].hasPrefix("1970-01-01T00:00:00Z "))
        precondition(!loaded.entries[0].contains("private-field") && loaded.entries[1].contains("PHONE_CODE_INVALID"))
        for _ in 0..<200 { journal.append(.clientClosed, at: date) }
        precondition(journal.entries.count == 160 && AuthJournal(defaults: defaults).entries.count == 160)
        journal.clear()
        precondition(AuthJournal(defaults: defaults).entries.isEmpty)
    }

    static func checkHistory() {
        precondition(HistoryPage.progress(ids: [90, 82, 82, -8, 70], from: 0) == .older(70))
        precondition(HistoryPage.progress(ids: [71, 70, 60], from: 70) == .older(60))
        precondition(HistoryPage.progress(ids: [71, 70], from: 70) == .end)
        precondition(HistoryPage.progress(ids: [], from: 0) == .end)
    }

    static func checkChatOrder() {
        var newest = RealChat(id: 1, title: "Newest")
        newest.lastMessageDate = 300
        newest.mainListOrder = 50
        var earlier = RealChat(id: 2, title: "First pinned")
        earlier.lastMessageDate = 5
        earlier.mainListOrder = Int64.max - 1
        earlier.isPinned = true
        var later = RealChat(id: 3, title: "Second pinned")
        later.lastMessageDate = 100
        later.mainListOrder = Int64.max - 2
        later.isPinned = true
        let archived = RealChat(id: 4, title: "Archived")
        let all = [newest, later, archived, earlier].sorted(by: RealChat.precedes)
        precondition(all.map(\.id) == [2, 3, 1, 4])
        precondition(all.filter(\.isInMainList).map(\.id) == [2, 3, 1])
    }
}

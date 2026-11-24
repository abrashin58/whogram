import Foundation

enum SessionCloseIntent: Equatable {
    case chooseAccount, switchAccount(UUID)
}

enum SessionClosePolicy {
    enum Action: Equatable { case chooseAccount, switchAccount(UUID), recover, pause }

    static func action(intent: SessionCloseIntent?, loggedOut: Bool, hadSecurityStop: Bool,
                       canRecover: Bool) -> Action {
        if loggedOut { return .chooseAccount }
        if let intent {
            switch intent {
            case .chooseAccount: return .chooseAccount
            case .switchAccount(let id): return .switchAccount(id)
            }
        }
        return !hadSecurityStop && canRecover ? .recover : .pause
    }
}

struct SessionRecoveryBudget {
    private var lastAttempt: [UUID: TimeInterval] = [:]
    private let interval: TimeInterval = 60

    mutating func consume(for id: UUID, at time: TimeInterval) -> Bool {
        if let previous = lastAttempt[id], time - previous < interval { return false }
        lastAttempt[id] = time
        return true
    }
}

struct TelegramAppIdentity: Codable, Equatable {
    enum ValidationError: LocalizedError {
        case invalidID, invalidHash

        var errorDescription: String? {
            switch self {
            case .invalidID: return "Введите числовой API ID своего приложения Telegram."
            case .invalidHash: return "API Hash должен содержать 32 шестнадцатеричных символа."
            }
        }
    }

    let apiID: Int32
    let apiHash: String
    // This random ID stays in a device-only Keychain item and is never sent to Telegram.
    let storageID: UUID
    static let previouslyPublicID: Int32 = 2086616

    init(id: String, hash: String, storageID: UUID = UUID()) throws {
        guard let apiID = Int32(id.trimmingCharacters(in: .whitespacesAndNewlines)), apiID > 0 else {
            throw ValidationError.invalidID
        }
        let hash = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hash.utf8.count == 32,
              hash.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw ValidationError.invalidHash
        }
        self.apiID = apiID
        self.apiHash = hash
        self.storageID = storageID
    }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: String(data.decode(Int32.self, forKey: .apiID)),
                      hash: data.decode(String.self, forKey: .apiHash),
                      storageID: data.decode(UUID.self, forKey: .storageID))
    }
}

struct SessionProfile: Codable, Identifiable, Equatable {
    fileprivate(set) var identity: TelegramAppIdentity
    let databaseKey: Data?
    var title: String
    var wasAuthorized = false
    var automaticRecoveryDisabled: Bool?
    var id: UUID { identity.storageID }

    func canResumeAtLaunch(hasLegacyDatabase: Bool = false) -> Bool {
        // A previously public identity still requires explicit confirmation.
        identity.apiID != TelegramAppIdentity.previouslyPublicID && automaticRecoveryDisabled != true
            && (wasAuthorized || (databaseKey == nil && hasLegacyDatabase))
    }
}

enum SessionCatalogError: LocalizedError {
    case invalid, missingDatabase, storage

    var errorDescription: String? {
        switch self {
        case .invalid: return "Каталог аккаунтов повреждён. Сохранённые базы не изменены."
        case .missingDatabase: return "База сохранённого сеанса недоступна. Новая база не будет создана."
        case .storage: return "Не удалось открыть локальное хранилище сеанса."
        }
    }
}

struct SessionCatalog: Codable, Equatable {
    private(set) var profiles: [SessionProfile] = []
    private(set) var selectedID: UUID?

    init(legacyIdentity: TelegramAppIdentity? = nil) {
        if let legacyIdentity {
            profiles = [.init(identity: legacyIdentity, databaseKey: nil,
                              title: "Аккаунт 1")]
            selectedID = legacyIdentity.storageID
        }
    }

    func validated() throws -> Self {
        let ids = Set(profiles.map(\.id))
        guard ids.count == profiles.count,
              profiles.allSatisfy({ $0.databaseKey == nil || $0.databaseKey?.count == 32 }),
              selectedID.map(ids.contains) ?? profiles.isEmpty else { throw SessionCatalogError.invalid }
        return self
    }

    func profile(_ id: UUID?) -> SessionProfile? {
        profiles.first { $0.id == id }
    }

    mutating func select(_ id: UUID) {
        guard profile(id) != nil else { return }
        selectedID = id
    }

    mutating func add(_ identity: TelegramAppIdentity, databaseKey: Data) {
        guard profile(identity.storageID) == nil, databaseKey.count == 32 else { return }
        profiles.append(.init(identity: identity, databaseKey: databaseKey, title: "Аккаунт \(profiles.count + 1)"))
        select(identity.storageID)
    }

    mutating func confirmAuthorization(for id: UUID, title: String? = nil) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].wasAuthorized = true
        profiles[index].automaticRecoveryDisabled = nil
        if let title, !title.isEmpty { profiles[index].title = title }
    }

    mutating func confirmLocalLogout(for id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].wasAuthorized = false
        profiles[index].automaticRecoveryDisabled = true
    }

    mutating func updateIdentity(for storageID: UUID, id: String, hash: String) throws {
        guard let index = profiles.firstIndex(where: { $0.id == storageID }) else { throw SessionCatalogError.invalid }
        profiles[index].identity = try TelegramAppIdentity(id: id, hash: hash, storageID: storageID)
        selectedID = storageID
    }
}

enum SessionRequestPolicy {
    enum Scope { case ordinary, bootstrap, authentication, confirmedLocalLogout, disconnect }

    static func allows(_ type: String?, scope: Scope) -> Bool {
        guard let type, !type.isEmpty else { return false }
        switch scope {
        case .bootstrap:
            return type == "setTdlibParameters"
        case .authentication:
            return authMethods.contains(type)
        case .confirmedLocalLogout:
            return type == "logOut"
        case .disconnect:
            return type == "close"
        case .ordinary:
            return !blocked.contains(type) && !authMethods.contains(type)
                && type != "logOut" && type != "setTdlibParameters"
        }
    }

    private static let authMethods: Set<String> = [
        "setAuthenticationPhoneNumber", "checkAuthenticationCode", "checkAuthenticationPassword",
        "setAuthenticationEmailAddress", "checkAuthenticationEmailCode", "resendAuthenticationCode"
    ]

    static func matchesAuthState(_ type: String?, state: String) -> Bool {
        switch (type, state) {
        case ("setAuthenticationPhoneNumber", "authorizationStateWaitPhoneNumber"),
             ("checkAuthenticationCode", "authorizationStateWaitCode"),
             ("resendAuthenticationCode", "authorizationStateWaitCode"),
             ("checkAuthenticationPassword", "authorizationStateWaitPassword"),
             ("setAuthenticationEmailAddress", "authorizationStateWaitEmailAddress"),
             ("checkAuthenticationEmailCode", "authorizationStateWaitEmailCode"):
            return true
        default:
            return false
        }
    }
    private static let blocked: Set<String> = [
        "terminateSession", "terminateAllOtherSessions", "terminateWebAppSession",
        "terminateAllWebAppSessions", "deleteAccount", "destroy", "close",
        "setInactiveSessionTtl", "resetAuthorizations", "resetAuthorization"
    ]

    static func securityCode(in message: String) -> String? {
        let codes = ["API_ID_PUBLISHED_FLOOD", "API_ID_INVALID", "CONNECTION_API_ID_INVALID",
                     "AUTH_KEY_DUPLICATED", "SESSION_REVOKED", "SESSION_EXPIRED", "UPDATE_APP_TO_LOGIN"]
        let tokens = message.split(whereSeparator: { !$0.isASCII || !($0.isLetter || $0.isNumber || $0 == "_") })
        return codes.first(where: { code in tokens.contains(where: { $0 == code }) })
    }
}

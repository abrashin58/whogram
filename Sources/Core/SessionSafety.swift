import Foundation

struct SessionStartupGate {
    private(set) var needsApproval = true

    mutating func approve(hasIdentity: Bool) -> Bool {
        guard needsApproval, hasIdentity else { return false }
        needsApproval = false
        return true
    }

    mutating func didClose() { needsApproval = true }
}

struct TelegramAppIdentity: Codable, Equatable {
    enum ValidationError: LocalizedError {
        case invalidID, retiredID, invalidHash

        var errorDescription: String? {
            switch self {
            case .invalidID: return "Введите числовой API ID своего приложения Telegram."
            case .retiredID: return "Старый публичный API ID Whogram отключён. Укажите API ID своего приложения."
            case .invalidHash: return "API Hash должен содержать 32 шестнадцатеричных символа."
            }
        }
    }

    let apiID: Int32
    let apiHash: String
    // This random ID stays in a device-only Keychain item and is never sent to Telegram.
    let storageID: UUID

    init(id: String, hash: String, storageID: UUID = UUID()) throws {
        guard let apiID = Int32(id.trimmingCharacters(in: .whitespacesAndNewlines)), apiID > 0 else {
            throw ValidationError.invalidID
        }
        guard apiID != 2086616 else { throw ValidationError.retiredID }
        let hash = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard hash.utf8.count == 32,
              hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
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

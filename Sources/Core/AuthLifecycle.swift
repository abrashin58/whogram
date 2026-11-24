import Foundation

enum AuthPhase: String {
    case idle, initializing
    case parameters = "authorizationStateWaitTdlibParameters"
    case phone = "authorizationStateWaitPhoneNumber"
    case premium = "authorizationStateWaitPremiumPurchase"
    case email = "authorizationStateWaitEmailAddress"
    case emailCode = "authorizationStateWaitEmailCode"
    case code = "authorizationStateWaitCode"
    case deviceConfirmation = "authorizationStateWaitOtherDeviceConfirmation"
    case registration = "authorizationStateWaitRegistration"
    case password = "authorizationStateWaitPassword"
    case ready = "authorizationStateReady"
    case loggingOut = "authorizationStateLoggingOut"
    case closing = "authorizationStateClosing"
    case closed = "authorizationStateClosed"
    case unsupported

    init(update: String) {
        let known = Self(rawValue: update)
        self = update.hasPrefix("authorizationState") ? known ?? .unsupported : .unsupported
    }
}

enum AuthMethod: String {
    case bootstrap = "setTdlibParameters"
    case phone = "setAuthenticationPhoneNumber"
    case code = "checkAuthenticationCode"
    case password = "checkAuthenticationPassword"
    case email = "setAuthenticationEmailAddress"
    case emailCode = "checkAuthenticationEmailCode"
    case resend = "resendAuthenticationCode"
    case register = "registerUser"
    case qr = "requestQrCodeAuthentication"

    func allowed(in phase: AuthPhase) -> Bool {
        switch (self, phase) {
        case (.bootstrap, .parameters), (.phone, .phone), (.code, .code), (.password, .password),
             (.email, .email), (.emailCode, .emailCode), (.resend, .code), (.resend, .emailCode),
             (.register, .registration), (.qr, .phone): return true
        default: return false
        }
    }

    var canFinishWithoutNewPhase: Bool { self == .resend || self == .emailCode || self == .register }
}

struct AuthLifecycle {
    struct Operation: Equatable {
        let token: UUID
        let method: AuthMethod
        let phase: AuthPhase
    }

    enum Update: Equatable { case advanced, refreshed, rejected }
    enum Reply: Equatable { case stale, finished, waitingForUpdate }

    private(set) var phase = AuthPhase.idle
    private(set) var operation: Operation?
    private(set) var timedOut = false
    private var observedRefresh = false
    private var receivedSuccess = false

    mutating func startClient() {
        clearOperation()
        phase = .initializing
    }

    mutating func observe(_ next: AuthPhase) -> Update {
        guard phase != .idle, phase != .closed, next != .initializing, next != .idle,
              phase != .closing || next == .closing || next == .closed,
              phase != .loggingOut || next == .loggingOut || next == .closing || next == .closed,
              phase != .ready || [.ready, .loggingOut, .closing, .closed].contains(next),
              next != .parameters || phase == .initializing || phase == .parameters else { return .rejected }
        if phase == next {
            if let operation, operation.method.canFinishWithoutNewPhase {
                observedRefresh = true
                if receivedSuccess { clearOperation() }
            }
            return .refreshed
        }
        phase = next
        clearOperation()
        return .advanced
    }

    mutating func begin(_ method: AuthMethod) -> Operation? {
        guard operation == nil, method.allowed(in: phase) else { return nil }
        let next = Operation(token: UUID(), method: method, phase: phase)
        operation = next
        return next
    }

    mutating func reply(to operation: Operation, ok: Bool) -> Reply {
        guard self.operation == operation else { return .stale }
        if !ok || (operation.method.canFinishWithoutNewPhase && observedRefresh) {
            clearOperation()
            return .finished
        }
        receivedSuccess = true
        return .waitingForUpdate
    }

    @discardableResult
    mutating func expire(_ operation: Operation) -> Bool {
        guard self.operation == operation, !timedOut else { return false }
        // The request may still be executing inside TDLib. Keep the token and
        // guard against duplicate submissions until a response or a new client.
        timedOut = true
        return true
    }

    private mutating func clearOperation() {
        operation = nil
        timedOut = false
        receivedSuccess = false
        observedRefresh = false
    }
}

struct AuthJournal {
    enum Event {
        case clientCreated, clientClosed, coldResume, automaticRecovery, manualRecovery
        case keychainUnavailable, directoryUnavailable, missingDatabase, nativeLoggingUnavailable
        case startupTimeout, operationTimeout(AuthMethod), closingTimeout
        case transition(AuthPhase, AuthPhase, AuthLifecycle.Update)
        case request(AuthMethod), response(AuthMethod, Int?, String?)
        case closeRequested, logoutRequested
        case closeResponse(Int?), logoutResponse(Int?)

        var description: String {
            switch self {
            case .clientCreated: return "client.created"
            case .clientClosed: return "client.closed"
            case .coldResume: return "recovery.cold-start"
            case .automaticRecovery: return "recovery.automatic"
            case .manualRecovery: return "recovery.manual"
            case .keychainUnavailable: return "failed.keychain-unavailable"
            case .directoryUnavailable: return "failed.session-directory-unavailable"
            case .missingDatabase: return "failed.session-binlog-missing"
            case .nativeLoggingUnavailable: return "failed.native-logging-control"
            case .startupTimeout: return "failed.timeout-first-update"
            case .operationTimeout(let method): return "failed.timeout \(method.rawValue)"
            case .closingTimeout: return "failed.timeout-close (client still owned)"
            case let .transition(from, to, result): return "state.\(result) \(from.rawValue) -> \(to.rawValue)"
            case .request(let method): return "request \(method.rawValue)"
            case let .response(method, code, message):
                guard let code else { return "response \(method.rawValue) OK" }
                // Only fixed labels from the allowlist may leave the parser.
                return "response \(method.rawValue) error=\(code) \(Self.safeReason(code: code, message: message))"
            case .closeRequested: return "request close"
            case .logoutRequested: return "request logOut"
            case .closeResponse(let code): return code.map { "response close error=\($0)" } ?? "response close OK"
            case .logoutResponse(let code): return code.map { "response logOut error=\($0)" } ?? "response logOut OK"
            }
        }

        static func safeReason(code: Int, message: String?) -> String {
            let known = ["PHONE_NUMBER_INVALID", "PHONE_CODE_INVALID", "PHONE_CODE_EXPIRED", "PASSWORD_HASH_INVALID",
                         "EMAIL_INVALID", "EMAIL_VERIFY_EXPIRED", "EMAIL_CODE_INVALID", "TASK_ALREADY_EXISTS",
                         "AUTH_RESTART", "Wrong database encryption key"]
            if let message {
                if let security = SessionRequestPolicy.securityCode(in: message) { return security }
                if let label = known.first(where: { $0 == message }) { return label }
            }
            switch code {
            case 0: return "transport-or-serialization"
            case 400: return "request-rejected"
            case 401: return "unauthorized"
            case 429: return "rate-limited"
            case 500...599: return "tdlib-or-server-unavailable"
            default: return "unclassified"
            }
        }
    }

    static let storageKey = "tdlib.auth.diagnostics.v1"
    private let defaults: UserDefaults
    private(set) var entries: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = Array((defaults.stringArray(forKey: Self.storageKey) ?? []).suffix(160))
    }

    mutating func append(_ event: Event, at date: Date = Date()) {
        entries.append("\(ISO8601DateFormatter().string(from: date)) \(event.description)")
        if entries.count > 160 { entries.removeFirst(entries.count - 160) }
        defaults.set(entries, forKey: Self.storageKey)
    }

    mutating func clear() {
        entries.removeAll()
        defaults.removeObject(forKey: Self.storageKey)
    }
}

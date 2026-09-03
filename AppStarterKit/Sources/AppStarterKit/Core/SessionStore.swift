import Foundation

/// The session this app persists between launches: DummyJSON's `accessToken` +
/// `refreshToken` pair, plus the id of the signed-in user (used by `ProfileModule` to
/// avoid a redundant network round trip for the id alone).
public nonisolated struct StoredSession: Sendable, Equatable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: Int

    public init(accessToken: String, refreshToken: String, userID: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
    }
}

/// Local persistence for the current session — the transversal piece every feature's
/// networking depends on (`AGENTS.md`/CoreNetworking `AGENTS.md`: "un Service, una llamada
/// a API" — but the BEARER TOKEN itself is app-wide state, read by
/// `BearerTokenInterceptor` and written by `LoginLogic`/the refresh retrier, exactly like
/// `AppFoundation/Examples/LoginApp`'s `SessionStoring`).
///
/// **Starter choice, documented (PRD-APP-01 §"Arquitectura")**: `UserDefaults`, not
/// Keychain — the fastest thing that works in a template a reader can `git clone` and run
/// against DummyJSON without provisioning Keychain access groups first. A production fork
/// swaps `UserDefaultsSessionStore` for a Keychain-backed implementation behind the SAME
/// `SessionStoring` protocol; nothing above the Store layer changes. See
/// `docs/INFORME-INTEGRACION.md` for why this stayed out of AppFoundation itself.
public protocol SessionStoring: Sendable {
    /// The current bearer token, or `nil` when signed out.
    func currentAccessToken() async -> String?

    /// The full stored session, or `nil` when signed out.
    func currentSession() async -> StoredSession?

    /// Persists `session` as the current one (login, or a successful refresh).
    func save(_ session: StoredSession) async

    /// Clears the current session (logout, or a refresh that could not recover it).
    func invalidate() async
}

/// The `SessionStoring` AppStarter runs with: an `actor` (not a lock-guarded class, M5 —
/// same reasoning as `LoginApp`'s `SessionStore`) wrapping `UserDefaults`.
///
/// The `SessionStoring` conformance is declared in a SEPARATE `extension` below, not
/// inline on this declaration (`actor UserDefaultsSessionStore: SessionStoring`) — with
/// `InferIsolatedConformances` + `defaultIsolation(MainActor)` both active (the
/// swiftSettings AppFoundation/CoreNetworking's own docs tell every consumer to copy,
/// `GettingStarted.md`), an inline conformance to a `Sendable` protocol with `async`
/// requirements makes THIS actor's own synchronous `init` fail to compile
/// ("actor-isolated property 'defaults' can not be mutated from the main actor") even
/// though `init` only assigns the actor's own stored properties. Moving the conformance
/// to an `extension` avoids it; reproduced in isolation and reported upstream — see
/// `docs/INFORME-INTEGRACION.md` and `docs/ISSUES.md`.
public actor UserDefaultsSessionStore {
    private let defaults: UserDefaults
    private let key = "com.appstarter.session"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func loadStoredSession() -> StoredSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }
}

extension UserDefaultsSessionStore: SessionStoring {
    public func currentAccessToken() async -> String? {
        loadStoredSession()?.accessToken
    }

    public func currentSession() async -> StoredSession? {
        loadStoredSession()
    }

    public func save(_ session: StoredSession) async {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    public func invalidate() async {
        defaults.removeObject(forKey: key)
    }
}

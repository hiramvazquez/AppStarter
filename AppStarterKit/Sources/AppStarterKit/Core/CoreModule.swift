import AppFoundation
import CoreNetworking
import Foundation

/// Registers everything that isn't owned by a single feature: navigation (`Coordinator`/
/// `Router`), the session store, app-wide session/refresh observability, and BOTH
/// `APIService` instances this app needs — an unauthenticated one for `/auth/login` and
/// `/auth/refresh` (`AuthServicing`), and the authenticated one every other feature
/// resolves as `APIServiceProtocol` (`NetworkingWiring.swift`).
///
/// Must be registered FIRST in `Container.shared.register(modules:)` conceptually (every
/// other feature module resolves `APIServiceProtocol`/`SessionStoring`/`Router<AppRoute>`
/// from it) — though because every `Container` factory is lazy, what actually matters is
/// that it is registered before the first `resolve()` call, not before the other modules'
/// `register(in:)` calls (`AppStarterApp.swift` registers it first anyway, for readability).
public struct CoreModule: DependencyModule {
    private let baseURL: URL
    /// `expiresInMins` DummyJSON's `/auth/refresh` is called with — kept separate from
    /// `LoginLogic`'s (login) constant so a future caller can shorten just the refresh
    /// window without touching how long a fresh login lasts.
    private let refreshExpiresInMinutes: Int
    private let transport: (any HTTPTransport)?

    /// - Parameters:
    ///   - baseURL: DummyJSON's base URL (`https://dummyjson.com`).
    ///   - refreshExpiresInMinutes: Forwarded to every `/auth/refresh` call.
    ///   - transport: Overrides the transport for BOTH `APIService` instances — used by
    ///     UI tests (`-UITestOffline`, `InMemoryTransport` with recorded DummyJSON
    ///     responses). `nil` (the default) uses `URLSessionTransport` against the real API.
    public init(baseURL: URL, refreshExpiresInMinutes: Int = 60, transport: (any HTTPTransport)? = nil) {
        self.baseURL = baseURL
        self.refreshExpiresInMinutes = refreshExpiresInMinutes
        self.transport = transport
    }

    public func register(in container: Container) {
        // MARK: Navigation
        container.register(Coordinator<AppRoute>.self) { _ in Coordinator(root: .login) }
        container.register((any Router<AppRoute>).self) { c in c.resolve(Coordinator<AppRoute>.self) }

        // MARK: Session
        container.register(SessionStoring.self) { _ in UserDefaultsSessionStore() }
        container.register(AppSessionState.self) { c in AppSessionState(router: c.resolve()) }
        container.register(SessionExpiring.self) { c in c.resolve(AppSessionState.self) }
        container.register(RefreshActivityLog.self) { _ in RefreshActivityLog() }

        // MARK: Networking — unauthenticated (login/refresh only)
        let configuration = NetworkingConfiguration(baseURL: baseURL)
        container.register(AuthServicing.self) { [transport] _ in
            let rawTransport = transport ?? URLSessionTransport()
            let rawAPI = APIService(configuration: configuration, transport: rawTransport)
            return AuthService(api: rawAPI)
        }

        // MARK: Networking — authenticated (every other feature)
        container.register(APIServiceProtocol.self) { [transport, refreshExpiresInMinutes] c in
            makeAuthenticatedAPIService(
                configuration: configuration,
                transport: transport ?? URLSessionTransport(),
                authService: c.resolve(),
                sessionStore: c.resolve(),
                sessionExpiring: c.resolve(),
                refreshLog: c.resolve(RefreshActivityLog.self),
                refreshExpiresInMinutes: refreshExpiresInMinutes
            )
        }
    }
}

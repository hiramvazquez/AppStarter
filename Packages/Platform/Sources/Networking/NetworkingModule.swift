import AppFoundation
import CoreNetworking
import Domain
import Foundation

/// Registers everything cross-cutting about networking and session state that isn't
/// owned by a single feature: the session store, app-wide session/refresh observability,
/// and BOTH `APIService` instances this app needs — an unauthenticated one for
/// `/auth/login` and `/auth/refresh` (`AuthServicing`), and the authenticated one every
/// other feature resolves as `APIServiceProtocol` (`NetworkingWiring.swift`). Navigation
/// (`Coordinator<AppRoute>`/`Router<AppRoute>`) is registered by `App/AppModule.swift`'s
/// `PlatformModule` instead — the `archinit --multi` composition root, not duplicated
/// here.
///
/// Registration order doesn't matter for correctness (every `Container` factory is lazy —
/// what matters is that every module is registered before the first `resolve()` call),
/// but `App/AppModule.swift` registers `PlatformModule()` before this one for readability.
public struct NetworkingModule: DependencyModule {
    private let baseURL: URL
    /// `expiresInMins` DummyJSON's `/auth/refresh` is called with — kept separate from
    /// `LoginFeature`'s `LoginLogic` (login) constant so a future caller can shorten just
    /// the refresh window without touching how long a fresh login lasts.
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
        // MARK: Session
        container.register(SessionStoring.self) { _ in UserDefaultsSessionStore() }
        container.register(AppSessionState.self) { c in AppSessionState(router: c.resolve()) }
        container.register(SessionExpiring.self) { c in c.resolve(AppSessionState.self) }
        container.register(RefreshActivityLog.self) { _ in RefreshActivityLog() }

        // MARK: Settings (PRD-APP-02 tramo B item 2)
        //
        // Read ONCE, synchronously, here — not inside a `container.register` factory
        // closure that could run again later: `APIServiceProtocol`'s own factory below
        // closes over `sslPinning` at THIS registration, so a toggle in `Settings`
        // deliberately takes effect on the NEXT launch, not live (see `README.md`'s
        // pinning section for why a live-reconfigured singleton transport was rejected —
        // every `*Service` already resolved and cached its OWN `any APIServiceProtocol`
        // reference by the time a running app's `Settings` screen could change it).
        let persistedSettings = AppSettings.loadSynchronously()
        container.register(ThemeSettings.self) { _ in ThemeSettings(isBrand: persistedSettings.themeIsBrand) }
        let sslPinning = PinningPins.configuration(for: persistedSettings, host: baseURL.host ?? "")

        // MARK: Networking — unauthenticated (login/refresh only)
        let configuration = NetworkingConfiguration(baseURL: baseURL)
        container.register(AuthServicing.self) { [transport, sslPinning] _ in
            let rawTransport = transport ?? URLSessionTransport(pinning: sslPinning)
            let rawAPI = APIService(configuration: configuration, transport: rawTransport)
            return AuthService(api: rawAPI)
        }

        // MARK: Networking — authenticated (every other feature)
        container.register(APIServiceProtocol.self) { [transport, sslPinning, refreshExpiresInMinutes] c in
            makeAuthenticatedAPIService(
                configuration: configuration,
                transport: transport ?? URLSessionTransport(pinning: sslPinning),
                authService: c.resolve(),
                sessionStore: c.resolve(),
                sessionExpiring: c.resolve(),
                refreshLog: c.resolve(RefreshActivityLog.self),
                refreshExpiresInMinutes: refreshExpiresInMinutes
            )
        }
    }
}

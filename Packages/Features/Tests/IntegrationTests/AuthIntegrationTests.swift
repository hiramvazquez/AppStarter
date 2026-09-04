import CoreNetworking
import Domain
import Foundation
import LoginFeature
import Networking
import PlatformTestSupport
import ProductsFeature
import ProfileFeature
import Testing

/// Real network, against the real DummyJSON API — `.disabled` by default (PRD-APP-01),
/// activated with `INTEGRATION=1`:
///
/// ```bash
/// INTEGRATION=1 swift test --package-path Packages/Features --filter AuthIntegrationTests
/// ```
///
/// Covers exactly what the PRD asks for: a real login, a real products fetch, and a real
/// `/auth/refresh` call with `expiresInMins: 1`. The 401 → refresh → retry PIPELINE
/// itself (this app's own wiring, `makeAuthenticatedAPIService`) is proven
/// deterministically against `InMemoryTransport` in `Packages/Platform`'s
/// `NetworkingWiringTests.swift`; this test instead proves the ENDPOINTS themselves work
/// against the real server, with the exact request shape `AuthService`/`ProductsService`/
/// `ProfileService` send.
///
/// Lives in its own `IntegrationTests` target (`Packages/Features/Package.swift`, outside
/// the `archinit:features-*` markers) because it is genuinely cross-feature: it drives
/// `AuthService` (`Networking`), `ProductsService` (`ProductsFeature`) and
/// `ProfileService` (`ProfileFeature`) together — no single `*FeatureTests` target can
/// depend on another feature's target without doing the same (R13 only applies to
/// production code, not `Tests/**`, but a dedicated integration target keeps that
/// exception visible instead of hiding it inside one feature's own test target).
@Suite(
    "DummyJSON integration",
    .enabled(if: ProcessInfo.processInfo.environment["INTEGRATION"] == "1")
)
struct AuthIntegrationTests {
    private static let baseURL = URL(string: "https://dummyjson.com")!

    @Test("Login real, productos reales, y refresh real con expiresInMins: 1")
    func loginProductsAndRefresh() async throws {
        let configuration = NetworkingConfiguration(baseURL: Self.baseURL)
        let api = APIService(configuration: configuration)

        // 1. Login real.
        let authService = AuthService(api: api)
        let session = try await authService.login(username: "emilys", password: "emilyspass", expiresInMinutes: 60)
        #expect(!session.tokens.accessToken.isEmpty)
        #expect(!session.tokens.refreshToken.isEmpty)
        #expect(session.userID > 0)

        // 2. Productos reales.
        let productsService = ProductsService(api: api)
        let page = try await productsService.fetchProducts(limit: 5, skip: 0)
        #expect(page.items.count == 5)
        #expect(page.total > 0)

        let product = try await productsService.fetchProduct(id: page.items[0].id)
        #expect(product.id == page.items[0].id)

        // 3. Refresh real con expiresInMins: 1 — el mismo `AuthService`, la misma
        // `RefreshRequest` que dispara `makeAuthenticatedAPIService` en producción.
        let refreshed = try await authService.refresh(refreshToken: session.tokens.refreshToken, expiresInMinutes: 1)
        #expect(!refreshed.accessToken.isEmpty)
        #expect(refreshed.accessToken != session.tokens.accessToken)

        // Y GET /auth/me con el token recién refrescado, para cerrar el círculo: el
        // access token que acaba de emitir /auth/refresh es válido de verdad.
        let authenticatedAPI = APIService(
            configuration: configuration,
            interceptors: [BearerTokenInterceptor { refreshed.accessToken }]
        )
        let profileService = ProfileService(api: authenticatedAPI)
        let profile = try await profileService.me()
        #expect(profile.username == "emilys")
    }

    @Test("Un login con credenciales inválidas contra el servidor real devuelve 400 (.invalidCredentials)")
    func invalidLoginMapsToInvalidCredentials() async {
        let configuration = NetworkingConfiguration(baseURL: Self.baseURL)
        let authService = AuthService(api: APIService(configuration: configuration))
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: authService, sessionStore: sessionStore)

        await #expect(throws: LoginError.invalidCredentials) {
            try await logic.login(username: "emilys", password: "not-the-real-password")
        }
    }
}

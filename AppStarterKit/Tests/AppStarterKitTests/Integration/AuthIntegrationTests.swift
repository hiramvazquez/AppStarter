import CoreNetworking
import Foundation
import Testing

@testable import AppStarterKit

/// Real network, against the real DummyJSON API — `.disabled` by default (PRD-APP-01),
/// activated with `INTEGRATION=1`:
///
/// ```bash
/// INTEGRATION=1 swift test --filter AuthIntegrationTests
/// ```
///
/// Covers exactly what the PRD asks for: a real login, a real products fetch, and a real
/// `/auth/refresh` call with `expiresInMins: 1`. The 401 → refresh → retry PIPELINE
/// itself (this app's own wiring, `makeAuthenticatedAPIService`) is proven deterministically
/// against `InMemoryTransport` in `Core/NetworkingWiringTests.swift` — waiting ~60s for a
/// real access token to expire here would make this suite slow without exercising any
/// code this app doesn't already control end to end; this test instead proves the ENDPOINT
/// (`/auth/refresh`) itself works against the real server, with the exact request shape
/// `AuthService` sends.
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

import CoreNetworking
import Domain
import Foundation

// MARK: - The domain model

/// What a successful login produces. `Sendable`/`Equatable` — crosses actor boundaries
/// and is what `AuthServicing` (never a DTO, M2) hands back. Lives next to
/// `AuthServicing`, not in `Domain`: only the auth flow (`Networking`'s own wiring +
/// `LoginFeature`) ever sees it, unlike `Product`/`UserProfile`, which several
/// independent features depend on.
public nonisolated struct AuthTokens: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public nonisolated struct AuthSession: Sendable, Equatable {
    public let tokens: AuthTokens
    public let userID: Int

    public init(tokens: AuthTokens, userID: Int) {
        self.tokens = tokens
        self.userID = userID
    }
}

// MARK: - The request / response DTOs (M2: only this file ever sees them)

struct LoginRequest: BaseRequest {
    struct Body: Encodable, Sendable {
        let username: String
        let password: String
        let expiresInMins: Int
    }

    struct Response: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
        let id: Int
    }

    let path = "/auth/login"
    let method = HTTPMethod.post
    let body: Body?

    init(username: String, password: String, expiresInMins: Int) {
        self.body = Body(username: username, password: password, expiresInMins: expiresInMins)
    }
}

struct RefreshRequest: BaseRequest {
    struct Body: Encodable, Sendable {
        let refreshToken: String
        let expiresInMins: Int
    }

    struct Response: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
    }

    let path = "/auth/refresh"
    let method = HTTPMethod.post
    let body: Body?

    init(refreshToken: String, expiresInMins: Int) {
        self.body = Body(refreshToken: refreshToken, expiresInMins: expiresInMins)
    }
}

// MARK: - The service

/// Two DummyJSON calls that share one concern — issuing and renewing this app's session —
/// so they stay in a single `Service`, per CoreNetworking `AGENTS.md`: "si necesita más de
/// una llamada, sigue siendo el único sitio que lo hace". `LoginFeature`'s `LoginLogic`
/// uses `login`; this same module's `NetworkingWiring.swift` (the `TokenRefresher`
/// closure) uses `refresh` — neither sees `LoginRequest`/`RefreshRequest` or
/// `APIServiceProtocol` directly.
///
/// Lives in `Networking`, not `Domain` (`.archlint.yml`: `Domain` only imports
/// `Foundation`) and not inside `LoginFeature` (this module's own composition root,
/// `NetworkingModule`, constructs `AuthService` directly for the UNauthenticated
/// `APIService` — `LoginFeature` only ever resolves `any AuthServicing` from the
/// `Container`, it never constructs this type).
public protocol AuthServicing: Sendable {
    func login(username: String, password: String, expiresInMinutes: Int) async throws(APIError) -> AuthSession
    func refresh(refreshToken: String, expiresInMinutes: Int) async throws(APIError) -> AuthTokens
}

/// The ONLY type in this app that references `APIServiceProtocol`/`BaseRequest` for
/// `/auth/login` and `/auth/refresh`.
public struct AuthService: AuthServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func login(username: String, password: String, expiresInMinutes: Int) async throws(APIError) -> AuthSession {
        let response = try await call(
            LoginRequest(username: username, password: password, expiresInMins: expiresInMinutes)
        )
        return AuthSession(
            tokens: AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken),
            userID: response.id
        )
    }

    public func refresh(refreshToken: String, expiresInMinutes: Int) async throws(APIError) -> AuthTokens {
        let response = try await call(RefreshRequest(refreshToken: refreshToken, expiresInMins: expiresInMinutes))
        return AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
    }
}

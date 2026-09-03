import CoreNetworking
import Foundation

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
/// una llamada, sigue siendo el único sitio que lo hace". `LoginLogic` uses `login`;
/// `NetworkingWiring.swift`'s `TokenRefresher` closure uses `refresh` — neither sees
/// `LoginRequest`/`RefreshRequest` or `APIServiceProtocol` directly.
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
        let response = try await call(LoginRequest(username: username, password: password, expiresInMins: expiresInMinutes))
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

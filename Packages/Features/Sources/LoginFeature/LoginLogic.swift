import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - Domain errors (M1)

/// Every way logging in can fail — never `APIError`, which stops at the `Logic`/`Service`
/// boundary.
public enum LoginError: DomainError, Equatable {
    case emptyUsername
    case emptyPassword
    case invalidCredentials
    case offline
    case server
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .offline, .server, .unknown: true
        case .emptyUsername, .emptyPassword, .invalidCredentials: false
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .emptyUsername:
            return ScreenError(title: "Falta el usuario", message: "Introduce tu nombre de usuario.")
        case .emptyPassword:
            return ScreenError(title: "Falta la contraseña", message: "Introduce tu contraseña.")
        case .invalidCredentials:
            return ScreenError(title: "Credenciales inválidas", message: "Comprueba tu usuario y contraseña.")
        case .offline:
            return ScreenError(title: "Sin conexión", message: "Comprueba tu red e inténtalo de nuevo.")
        case .server:
            return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `LoginViewModel` can ask its `Logic` for.
public protocol LoginLogicProtocol: Logic {
    /// Validates `username`/`password` locally, calls `AuthServicing`, and persists the
    /// resulting session through `SessionStoring`. Maps any failure to `LoginError`.
    func login(username: String, password: String) async throws
}

/// ALL of the Login feature's business logic: local validation, one call to
/// `AuthServicing` (`Networking`), persisting the session (`SessionStoring`, `Domain`) —
/// nothing else in the app calls `AuthServicing.login` or writes to `SessionStoring` on a
/// successful login.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class LoginLogic: LoginLogicProtocol {
    private let authService: any AuthServicing
    private let sessionStore: any SessionStoring
    /// DummyJSON's session length for THIS screen. The integration test
    /// (`AuthIntegrationTests`) drives `AuthServicing`/`SessionStoring` directly with a
    /// short-lived session instead of reconfiguring this value — this constant is what a
    /// real signed-in user gets.
    private let expiresInMinutes: Int

    public init(authService: any AuthServicing, sessionStore: any SessionStoring, expiresInMinutes: Int = 60) {
        self.authService = authService
        self.sessionStore = sessionStore
        self.expiresInMinutes = expiresInMinutes
    }

    public func login(username: String, password: String) async throws {
        guard !username.isEmpty else { throw LoginError.emptyUsername }
        guard !password.isEmpty else { throw LoginError.emptyPassword }

        do {
            let session = try await authService.login(
                username: username,
                password: password,
                expiresInMinutes: expiresInMinutes
            )
            await sessionStore.save(
                StoredSession(
                    accessToken: session.tokens.accessToken,
                    refreshToken: session.tokens.refreshToken,
                    userID: session.userID
                )
            )
        } catch {
            // `authService.login` is `throws(APIError)` (typed throws): `error` here is
            // already `APIError`, not `any Error`.
            throw Self.mapError(error)
        }
    }

    /// The ONE place `APIError` gets translated to `LoginError`. DummyJSON answers a bad
    /// username/password with `400 Bad Request` (`.client`), not `401` — verified against
    /// the real API (`docs/INFORME-INTEGRACION.md`).
    private static func mapError(_ error: APIError) -> LoginError {
        switch error.category {
        case .offline:
            return .offline
        case .unauthorized, .client:
            return .invalidCredentials
        case .server:
            return .server
        default:
            return .unknown
        }
    }
}

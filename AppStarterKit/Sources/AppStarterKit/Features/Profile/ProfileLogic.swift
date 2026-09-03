import AppFoundation
import CoreNetworking
import Foundation

// MARK: - The domain model

/// `Sendable`/`Equatable` — never the network `DTO` (M2), see `Services/ProfileService.swift`.
public nonisolated struct UserProfile: Sendable, Equatable {
    public let id: Int
    public let username: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let imageURL: URL?

    public init(id: Int, username: String, email: String, firstName: String, lastName: String, imageURL: URL?) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.imageURL = imageURL
    }
}

// MARK: - Domain errors (M1)

public enum ProfileError: DomainError, Equatable {
    case offline
    case unauthorized
    case server
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .unauthorized: false
        case .offline, .server, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: "Sin conexión", message: "Comprueba tu red e inténtalo de nuevo.")
        case .unauthorized:
            return ScreenError(title: "Sesión no válida", message: "Vuelve a iniciar sesión.")
        case .server:
            return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `ProfileViewModel` can ask its `Logic` for.
public protocol ProfileLogicProtocol: Logic {
    func loadProfile() async throws -> UserProfile

    /// Clears the local session. Deliberate — unlike `SessionExpiring.sessionDidExpire()`,
    /// this is the user's own choice, so it never throws or maps an error: there is
    /// nothing to recover from.
    func logout() async
}

/// ALL of the Profile feature's business logic: one call to `ProfileServicing`, and
/// clearing `SessionStoring` on an explicit logout.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class ProfileLogic: ProfileLogicProtocol {
    private let profileService: any ProfileServicing
    private let sessionStore: any SessionStoring

    public init(profileService: any ProfileServicing, sessionStore: any SessionStoring) {
        self.profileService = profileService
        self.sessionStore = sessionStore
    }

    public func loadProfile() async throws -> UserProfile {
        do {
            return try await profileService.me()
        } catch {
            throw Self.mapError(error)
        }
    }

    public func logout() async {
        await sessionStore.invalidate()
    }

    private static func mapError(_ error: APIError) -> ProfileError {
        switch error.category {
        case .offline: return .offline
        case .unauthorized: return .unauthorized
        case .server: return .server
        default: return .unknown
        }
    }
}

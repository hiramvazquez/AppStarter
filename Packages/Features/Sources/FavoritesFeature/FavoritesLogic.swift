import AppFoundation
import Domain
import Foundation

// MARK: - Domain errors (M1)

/// Every way reading/writing local favorites can fail — never a raw SwiftData error,
/// which stops at the `Logic`/`Store` boundary.
public enum FavoritesError: DomainError, Equatable {
    case storageFailure
    case unknown

    public var isRetryable: Bool { true }

    public var screenError: ScreenError {
        switch self {
        case .storageFailure:
            return ScreenError(title: "No se pudo leer", message: "Hubo un problema con el almacenamiento local.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `FavoritesViewModel` can ask its `Logic` for.
public protocol FavoritesLogicProtocol: Logic {
    func loadFavorites() async throws -> [Product]
    func remove(id: Int) async throws
    func clearAll() async throws
}

/// ALL of the Favorites feature's business logic: reads/removes through
/// `FavoritesStoring` (`Domain`), mapping any failure to `FavoritesError`.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class FavoritesLogic: FavoritesLogicProtocol {
    private let favoritesStore: any FavoritesStoring

    public init(favoritesStore: any FavoritesStoring) {
        self.favoritesStore = favoritesStore
    }

    public func loadFavorites() async throws -> [Product] {
        do {
            return try await favoritesStore.fetchAll()
        } catch {
            throw FavoritesError.storageFailure
        }
    }

    public func remove(id: Int) async throws {
        do {
            try await favoritesStore.remove(id: id)
        } catch {
            throw FavoritesError.storageFailure
        }
    }

    public func clearAll() async throws {
        do {
            try await favoritesStore.removeAll()
        } catch {
            throw FavoritesError.storageFailure
        }
    }
}

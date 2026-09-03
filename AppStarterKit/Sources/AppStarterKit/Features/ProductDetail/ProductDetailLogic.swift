import AppFoundation
import CoreNetworking
import Foundation

// MARK: - The domain model

/// What `ProductDetailView` renders: the product plus whether it's currently favorited.
/// `Sendable`/`Equatable` — never a DTO/`@Model` (M2).
public nonisolated struct ProductDetailState: Sendable, Equatable {
    public let product: Product
    public let isFavorite: Bool

    public init(product: Product, isFavorite: Bool) {
        self.product = product
        self.isFavorite = isFavorite
    }
}

// MARK: - Domain errors (M1)

public enum ProductDetailError: DomainError, Equatable {
    case offline
    case notFound
    case server
    case favoriteStorageFailure
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .notFound: false
        case .offline, .server, .favoriteStorageFailure, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: "Sin conexión", message: "Comprueba tu red e inténtalo de nuevo.")
        case .notFound:
            return ScreenError(title: "No encontrado", message: "Este producto ya no está disponible.")
        case .server:
            return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        case .favoriteStorageFailure:
            return ScreenError(title: "No se pudo guardar", message: "Hubo un problema al actualizar tus favoritos.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `ProductDetailViewModel` can ask its `Logic` for. This feature is the
/// `--api --local` variant: `load(id:)` combines a network call (`ProductsServicing`,
/// shared with `Products`/`Search`) with a local read (`FavoritesStoring`, shared with
/// `Favorites`) — neither `ProductDetailViewModel` nor this protocol's callers know that.
public protocol ProductDetailLogicProtocol: Logic {
    func load(id: Int) async throws -> ProductDetailState

    /// - Returns: The resulting favorite state (`true` = now favorited).
    @discardableResult
    func toggleFavorite(_ product: Product) async throws -> Bool
}

/// ALL of the ProductDetail feature's business logic: coordinates `ProductsServicing`
/// (network) and `FavoritesStoring` (local), and maps any failure to `ProductDetailError`.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class ProductDetailLogic: ProductDetailLogicProtocol {
    private let productsService: any ProductsServicing
    private let favoritesStore: any FavoritesStoring

    public init(productsService: any ProductsServicing, favoritesStore: any FavoritesStoring) {
        self.productsService = productsService
        self.favoritesStore = favoritesStore
    }

    public func load(id: Int) async throws -> ProductDetailState {
        do {
            let product = try await productsService.fetchProduct(id: id)
            let isFavorite = await favoritesStore.isFavorite(id: id)
            return ProductDetailState(product: product, isFavorite: isFavorite)
        } catch {
            // `productsService.fetchProduct` is `throws(APIError)`: `error` here is
            // already `APIError`, not `any Error`.
            throw Self.mapError(error)
        }
    }

    @discardableResult
    public func toggleFavorite(_ product: Product) async throws -> Bool {
        do {
            return try await favoritesStore.toggle(product)
        } catch {
            throw ProductDetailError.favoriteStorageFailure
        }
    }

    private static func mapError(_ error: APIError) -> ProductDetailError {
        switch error.category {
        case .offline: return .offline
        case .notFound: return .notFound
        case .server: return .server
        default: return .unknown
        }
    }
}

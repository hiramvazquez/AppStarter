import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

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
    /// La carga se canceló. Existe porque la spec `plataforma` lo exige de toda feature que
    /// lance una cancelación venida de la red: se mapea desde `APIError.Category.cancelled`
    /// en vez de caer en `.unknown`, no es reintentable, y `AppCancellationRecognizer` lo
    /// reconoce para que `BaseViewModel` no lo presente como error.
    ///
    /// Sin este caso, cancelar una carga pintaba un error a pantalla completa con
    /// «Reintentar» — sobre algo que el usuario acababa de cancelar.
    case cancelled
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .notFound, .cancelled: false
        case .offline, .server, .favoriteStorageFailure, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .notFound:
            return ScreenError(title: ErrorCopy.NotFound.title, message: ErrorCopy.NotFound.message)
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        case .favoriteStorageFailure:
            return ScreenError(title: "No se pudo guardar", message: "Hubo un problema al actualizar tus favoritos.")
        // No debería renderizarse: `AppCancellationRecognizer` intercepta el caso antes de que
        // `BaseViewModel` llame a `setError`. Está porque el `switch` es exhaustivo.
        case .cancelled:
            return ScreenError(title: ErrorCopy.Cancelled.title, message: ErrorCopy.Cancelled.message)
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        }
    }
}

// MARK: - Logic

/// Every operation `ProductDetailViewModel` can ask its `Logic` for. This feature is the
/// `--api --local` variant: `load(id:)` combines a network call (`ProductsServicing`,
/// `Networking` — shared with `Products`/`Search`) with a local read (`FavoritesStoring`,
/// `Domain` — shared with `Favorites`) — neither `ProductDetailViewModel` nor this
/// protocol's callers know that.
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
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

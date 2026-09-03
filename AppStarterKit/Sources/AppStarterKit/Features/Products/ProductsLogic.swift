import AppFoundation
import CoreNetworking
import Foundation

// MARK: - The domain model

/// What every screen that shows a product renders — `Products`, `ProductDetail`,
/// `Search`, `Favorites`. `Sendable`/`Equatable`/`Identifiable`, never the network `DTO`
/// (M2) — see `Services/ProductsService.swift`.
public nonisolated struct Product: Sendable, Equatable, Hashable, Identifiable {
    public let id: Int
    public let title: String
    public let description: String
    public let price: Double
    public let rating: Double
    public let thumbnailURL: URL?

    public init(id: Int, title: String, description: String, price: Double, rating: Double, thumbnailURL: URL?) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.rating = rating
        self.thumbnailURL = thumbnailURL
    }
}

/// One page of `GET /products`.
public nonisolated struct ProductsPage: Sendable, Equatable {
    public let items: [Product]
    public let total: Int
    public let skip: Int
    public let limit: Int

    public init(items: [Product], total: Int, skip: Int, limit: Int) {
        self.items = items
        self.total = total
        self.skip = skip
        self.limit = limit
    }

    /// Whether there are more products beyond this page.
    public var hasMore: Bool { skip + items.count < total }
}

// MARK: - Domain errors (M1)

public enum ProductsError: DomainError, Equatable {
    case offline
    case server
    case unknown

    public var isRetryable: Bool { true }

    public var screenError: ScreenError {
        switch self {
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

/// The paginated-list contract `ProductsViewModel` sequences: `loadPage(skip:)` for both
/// the first page (`skip: 0`) and every subsequent one (pull-to-refresh calls it again
/// with `skip: 0`, "load more" with the next offset) — a single call, not two, since
/// DummyJSON's `/products` has no separate cache to fall back on the way
/// `CatalogApp`'s local store does (this feature has no `--local` half).
public protocol ProductsLogicProtocol: Logic {
    /// Fixed page size every call uses.
    var pageSize: Int { get }

    func loadPage(skip: Int) async throws -> ProductsPage
}

/// ALL of the Products feature's business logic: one call to `ProductsServicing`, mapped
/// to `ProductsError` on failure.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class ProductsLogic: ProductsLogicProtocol {
    public let pageSize = 20

    private let productsService: any ProductsServicing

    public init(productsService: any ProductsServicing) {
        self.productsService = productsService
    }

    public func loadPage(skip: Int) async throws -> ProductsPage {
        do {
            return try await productsService.fetchProducts(limit: pageSize, skip: skip)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> ProductsError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        default: return .unknown
        }
    }
}

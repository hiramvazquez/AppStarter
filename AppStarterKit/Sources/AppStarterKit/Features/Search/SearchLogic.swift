import AppFoundation
import CoreNetworking
import Foundation

// MARK: - Domain errors (M1)

public enum SearchError: DomainError, Equatable {
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

/// Every operation `SearchViewModel` can ask its `Logic` for.
public protocol SearchLogicProtocol: Logic {
    func search(query: String) async throws -> [Product]
}

/// ALL of the Search feature's business logic: one call to `ProductsServicing` (shared
/// with `Products`/`ProductDetail`), mapped to `SearchError` on failure.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class SearchLogic: SearchLogicProtocol {
    private let productsService: any ProductsServicing

    public init(productsService: any ProductsServicing) {
        self.productsService = productsService
    }

    public func search(query: String) async throws -> [Product] {
        do {
            return try await productsService.search(query: query)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> SearchError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        default: return .unknown
        }
    }
}

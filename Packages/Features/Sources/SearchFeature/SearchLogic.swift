import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - Domain errors (M1)
//
// El error de esta feature es `CatalogError`, en `Networking`: Search y Products declaraban el
// mismo enum con otro nombre, y las dos traducen los fallos del mismo servicio.

// MARK: - Logic

/// Every operation `SearchViewModel` can ask its `Logic` for.
public protocol SearchLogicProtocol: Logic {
    func search(query: String) async throws -> [Product]
}

/// ALL of the Search feature's business logic: one call to `ProductsServicing`
/// (`Networking` — shared with `Products`/`ProductDetail`), mapped to `CatalogError` on
/// failure.
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
            throw CatalogError.from(error)
        }
    }
}

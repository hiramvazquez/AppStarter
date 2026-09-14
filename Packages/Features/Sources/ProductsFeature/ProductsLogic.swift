import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - Domain errors (M1)
//
// El error de esta feature es `CatalogError`, en `Networking`: Products y Search declaraban el
// mismo enum con otro nombre, y cuando `ErrorCopy` cambió hubo que tocar los dos.

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

/// ALL of the Products feature's business logic: one call to `ProductsServicing`
/// (`Networking`), mapped to `CatalogError` on failure.
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
            throw CatalogError.from(error)
        }
    }
}

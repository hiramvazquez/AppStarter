import CoreNetworking
import Domain
import Foundation

/// Three DummyJSON calls under one roof — list, single item, search — all mapping to
/// `Product` (`Domain`, never the network `DTO`, M2). Shared by three features
/// (`ProductsFeature` [owns the concrete `ProductsService`], `ProductDetailFeature`,
/// `SearchFeature`): each depends on `any ProductsServicing` through `init`, resolved from
/// the `Container` — never on the concrete type.
///
/// The protocol lives in `Networking` (not `Domain`, which only imports `Foundation`)
/// because it throws `APIError` (`CoreNetworking`); the concrete `ProductsService` and
/// its request DTOs stay in `ProductsFeature` — normal `Service`-layer code, per
/// `AGENTS.md` — since only `ProductsFeature` constructs it.
public protocol ProductsServicing: Sendable {
    func fetchProducts(limit: Int, skip: Int) async throws(APIError) -> ProductsPage
    func fetchProduct(id: Int) async throws(APIError) -> Product
    func search(query: String) async throws(APIError) -> [Product]
}

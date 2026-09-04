import AppFoundationTestSupport
import CoreNetworking
import Domain
import Foundation
import Networking

/// Stub that substitutes `ProductsServicing` — shared by `ProductsFeatureTests`,
/// `ProductDetailFeatureTests` and `SearchFeatureTests`, exactly like the production
/// `ProductsService` is shared across those three features.
///
/// `@unchecked Sendable` JUSTIFICADO: same as `AuthServiceMock` (`LoginFeatureTests`,
/// feature-local) — configured once before exercising the logic under test, never
/// mutated concurrently with a read.
public final class ProductsServiceMock: ProductsServicing, @unchecked Sendable {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    public var pageToReturn = ProductsPage(items: [], total: 0, skip: 0, limit: 20)
    public var productToReturn = Product(id: 1, title: "Stub", description: "", price: 1, rating: 1, thumbnailURL: nil)
    public var searchResultsToReturn: [Product] = []
    public var errorToThrow: APIError?

    public init() {}

    public func fetchProducts(limit: Int, skip: Int) async throws(APIError) -> ProductsPage {
        if let errorToThrow { throw errorToThrow }
        return pageToReturn
    }

    public func fetchProduct(id: Int) async throws(APIError) -> Product {
        if let errorToThrow { throw errorToThrow }
        return productToReturn
    }

    public func search(query: String) async throws(APIError) -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return searchResultsToReturn
    }
}

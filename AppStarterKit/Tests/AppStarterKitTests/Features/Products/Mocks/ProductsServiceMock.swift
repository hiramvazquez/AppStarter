import AppFoundationTestSupport
import CoreNetworking
import Foundation

@testable import AppStarterKit

/// Stub that substitutes `ProductsServicing` — shared by `ProductsLogicTests`,
/// `ProductDetailLogicTests` and `SearchLogicTests`, exactly like the production
/// `ProductsService` is shared across those three features.
///
/// `@unchecked Sendable` JUSTIFICADO: same as `AuthServiceMock` — configured once before
/// exercising the logic under test, never mutated concurrently with a read.
final class ProductsServiceMock: ProductsServicing, @unchecked Sendable {
    var pageToReturn = ProductsPage(items: [], total: 0, skip: 0, limit: 20)
    var productToReturn = Product(id: 1, title: "Stub", description: "", price: 1, rating: 1, thumbnailURL: nil)
    var searchResultsToReturn: [Product] = []
    var errorToThrow: APIError?

    func fetchProducts(limit: Int, skip: Int) async throws(APIError) -> ProductsPage {
        if let errorToThrow { throw errorToThrow }
        return pageToReturn
    }

    func fetchProduct(id: Int) async throws(APIError) -> Product {
        if let errorToThrow { throw errorToThrow }
        return productToReturn
    }

    func search(query: String) async throws(APIError) -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return searchResultsToReturn
    }
}

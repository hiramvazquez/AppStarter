import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Testing

@testable import ProductsFeature

/// `ProductsService` tested against `MockAPIService` — request/response mapping only, no
/// real network, no retry pipeline (see `Packages/Platform`'s `NetworkingWiringTests` for
/// that).
@Suite("ProductsService")
struct ProductsServiceTests {
    @Test("fetchProducts(limit:skip:) maps the DTO page to a ProductsPage")
    func fetchProductsMapsPage() async throws {
        let mock = MockAPIService()
        mock.stub(
            GetProductsRequest.self,
            returning: GetProductsRequest.Response(
                products: [
                    GetProductsRequest.DTO(
                        id: 1,
                        title: "Essence Mascara",
                        description: "desc",
                        price: 9.99,
                        rating: 2.5,
                        thumbnail: "https://example.com/t.png"
                    )
                ],
                total: 100,
                skip: 0,
                limit: 20
            )
        )
        let service = ProductsService(api: mock)

        let page = try await service.fetchProducts(limit: 20, skip: 0)

        #expect(page.items.count == 1)
        #expect(page.items[0].title == "Essence Mascara")
        #expect(page.total == 100)
        #expect(page.hasMore)
    }

    @Test("fetchProduct(id:) propagates a service error")
    func fetchProductPropagatesError() async {
        let mock = MockAPIService()
        mock.stub(GetProductRequest.self, throwing: .stub(code: .httpStatus, statusCode: 404))
        let service = ProductsService(api: mock)

        await #expect(throws: APIError.self) {
            try await service.fetchProduct(id: 999)
        }
    }
}

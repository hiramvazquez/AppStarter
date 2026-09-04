import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import ProductsFeature

@Suite("ProductsLogic")
struct ProductsLogicTests {
    @Test("loadPage(skip:) returns what the service returns")
    func loadPageReturnsServiceResult() async throws {
        let service = ProductsServiceMock()
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        service.pageToReturn = ProductsPage(items: [product], total: 1, skip: 0, limit: 20)
        let logic = ProductsLogic(productsService: service)

        let page = try await logic.loadPage(skip: 0)

        #expect(page.items == [product])
    }

    @Test("An offline service failure maps to ProductsError.offline")
    func offlineFailureMapsToOffline() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .transport, underlying: URLError(.notConnectedToInternet))
        let logic = ProductsLogic(productsService: service)

        await #expect(throws: ProductsError.offline) {
            try await logic.loadPage(skip: 0)
        }
    }

    @Test("A 5xx service failure maps to ProductsError.server")
    func serverFailureMapsToServer() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 500)
        let logic = ProductsLogic(productsService: service)

        await #expect(throws: ProductsError.server) {
            try await logic.loadPage(skip: 0)
        }
    }
}

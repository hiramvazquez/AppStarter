import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import SearchFeature

@Suite("SearchLogic")
struct SearchLogicTests {
    @Test("search(query:) returns what the service returns")
    func searchReturnsServiceResult() async throws {
        let service = ProductsServiceMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        service.searchResultsToReturn = [product]
        let logic = SearchLogic(productsService: service)

        let results = try await logic.search(query: "phone")

        #expect(results == [product])
    }

    @Test("A 5xx service failure maps to SearchError.server")
    func serverFailureMapsToServer() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 500)
        let logic = SearchLogic(productsService: service)

        await #expect(throws: SearchError.server) {
            try await logic.search(query: "phone")
        }
    }
}

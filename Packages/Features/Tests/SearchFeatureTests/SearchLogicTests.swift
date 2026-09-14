import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Networking
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

    @Test("A 5xx service failure maps to CatalogError.server")
    func serverFailureMapsToServer() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 500)
        let logic = SearchLogic(productsService: service)

        await #expect(throws: CatalogError.server) {
            try await logic.search(query: "phone")
        }
    }
}

@Suite("CatalogError desde Search: cancelación")
struct SearchCatalogErrorCancelledTests {
    /// Pasa por `mapError` de verdad, con el mismo patrón que sus tests hermanos: si el
    /// caso `.cancelled` se cae del `switch`, esto se pone rojo.
    @Test("una cancelación del transporte mapea a .cancelled, no a .unknown")
    func cancelacionMapeaACancelled() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .cancelled, underlying: URLError(.cancelled))
        let logic = SearchLogic(productsService: service)

        await #expect(throws: CatalogError.cancelled) {
            _ = try await logic.search(query: "x")
        }
    }

    // `isRetryable` se comprueba en `NetworkingTests/CatalogErrorTests`, donde vive el tipo.
    // Aquí estaba duplicado con el test gemelo de Products: al unificar el error, los dos
    // cuerpos pasaron a ser idénticos y el detector los reportó como un grupo nuevo.
}

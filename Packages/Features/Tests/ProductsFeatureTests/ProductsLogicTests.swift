import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import Networking
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

    @Test("An offline service failure maps to CatalogError.offline")
    func offlineFailureMapsToOffline() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .transport, underlying: URLError(.notConnectedToInternet))
        let logic = ProductsLogic(productsService: service)

        await #expect(throws: CatalogError.offline) {
            try await logic.loadPage(skip: 0)
        }
    }

    @Test("A 5xx service failure maps to CatalogError.server")
    func serverFailureMapsToServer() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 500)
        let logic = ProductsLogic(productsService: service)

        await #expect(throws: CatalogError.server) {
            try await logic.loadPage(skip: 0)
        }
    }
}

@Suite("CatalogError desde Products: cancelación")
struct ProductsCatalogErrorCancelledTests {
    /// Pasa por `mapError` de verdad, con el mismo patrón que sus tests hermanos: si el
    /// caso `.cancelled` se cae del `switch`, esto se pone rojo.
    @Test("una cancelación del transporte mapea a .cancelled, no a .unknown")
    func cancelacionMapeaACancelled() async {
        let service = ProductsServiceMock()
        service.errorToThrow = .stub(code: .cancelled, underlying: URLError(.cancelled))
        let logic = ProductsLogic(productsService: service)

        await #expect(throws: CatalogError.cancelled) {
            try await logic.loadPage(skip: 0)
        }
    }

    // `isRetryable` se comprueba en `NetworkingTests/CatalogErrorTests`, donde vive el tipo.
    // Aquí estaba duplicado con el test gemelo de Search: al unificar el error, los dos cuerpos
    // pasaron a ser idénticos y el detector los reportó como un grupo nuevo.
}

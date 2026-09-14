import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import ProductDetailFeature

@Suite("ProductDetailLogic")
struct ProductDetailLogicTests {
    @Test("load(id:) combines the network product and the local favorite flag")
    func loadCombinesProductAndFavoriteFlag() async throws {
        let productsService = ProductsServiceMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        productsService.productToReturn = product
        let favoritesStore = FavoritesStoreMock(isFavoriteToReturn: true)
        let logic = ProductDetailLogic(productsService: productsService, favoritesStore: favoritesStore)

        let state = try await logic.load(id: 7)

        #expect(state.product == product)
        #expect(state.isFavorite)
    }

    @Test("toggleFavorite(_:) delegates to the favorites store and returns its result")
    func toggleFavoriteDelegatesToStore() async throws {
        let productsService = ProductsServiceMock()
        let favoritesStore = FavoritesStoreMock(isFavoriteToReturn: false)
        let logic = ProductDetailLogic(productsService: productsService, favoritesStore: favoritesStore)
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)

        let result = try await logic.toggleFavorite(product)

        #expect(result)
        #expect(await favoritesStore.toggleCalls.calls == [7])
    }

    @Test("A 404 service failure maps to ProductDetailError.notFound")
    func notFoundFailureMaps() async {
        let productsService = ProductsServiceMock()
        productsService.errorToThrow = .stub(code: .httpStatus, statusCode: 404)
        let favoritesStore = FavoritesStoreMock()
        let logic = ProductDetailLogic(productsService: productsService, favoritesStore: favoritesStore)

        await #expect(throws: ProductDetailError.notFound) {
            try await logic.load(id: 999)
        }
    }

    /// Pasa por `mapError` de verdad: si `.cancelled` vuelve a caer en el `default`, esto se
    /// pone rojo. Antes caía, y cancelar una carga pintaba error a pantalla completa con
    /// «Reintentar» — sobre algo que el usuario acababa de cancelar.
    @Test("una cancelación del transporte mapea a ProductDetailError.cancelled, no a .unknown")
    func cancelacionMapeaACancelled() async {
        let productsService = ProductsServiceMock()
        productsService.errorToThrow = .stub(code: .cancelled, underlying: URLError(.cancelled))
        let favoritesStore = FavoritesStoreMock()
        let logic = ProductDetailLogic(productsService: productsService, favoritesStore: favoritesStore)

        await #expect(throws: ProductDetailError.cancelled) {
            try await logic.load(id: 7)
        }
    }

    @Test("una cancelación NO es reintentable")
    func cancelacionNoEsReintentable() {
        #expect(ProductDetailError.cancelled.isRetryable == false)
        #expect(ProductDetailError.server.isRetryable == true)
    }
}

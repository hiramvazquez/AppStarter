import CoreNetworking
import Foundation
import Testing

@testable import AppStarterKit

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
}

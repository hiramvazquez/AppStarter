import AppFoundationTestSupport
import Domain
import Foundation

@testable import ProductDetailFeature

final class ProductDetailLogicMock: ProductDetailLogicProtocol {
    let loadCalls = SpyRecorder<Int>()
    var stateToReturn = ProductDetailState(
        product: Product(id: 1, title: "Stub", description: "", price: 1, rating: 1, thumbnailURL: nil),
        isFavorite: false
    )
    var toggleResult = true
    var errorToThrow: (any Error)?

    func load(id: Int) async throws -> ProductDetailState {
        await loadCalls.record(id)
        if let errorToThrow { throw errorToThrow }
        return stateToReturn
    }

    func toggleFavorite(_ product: Product) async throws -> Bool {
        if let errorToThrow { throw errorToThrow }
        return toggleResult
    }
}

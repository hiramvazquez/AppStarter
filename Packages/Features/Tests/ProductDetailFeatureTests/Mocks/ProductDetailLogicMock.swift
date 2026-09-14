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

    /// Deja parada una llamada concreta. Recibe el número de llamada (1, 2, …) para poder
    /// soltar UNA y dejar la otra en vuelo, que es lo que hace falta para observar qué le pasa
    /// a la fase cuando una carga supera a otra. Mismo mecanismo que `CartLogicMock`.
    var gate: (@Sendable (Int) async -> Void)?
    private var loadCallCount = 0

    func load(id: Int) async throws -> ProductDetailState {
        await loadCalls.record(id)
        loadCallCount += 1
        let llamada = loadCallCount
        await gate?(llamada)
        if let errorToThrow { throw errorToThrow }
        return stateToReturn
    }

    func toggleFavorite(_ product: Product) async throws -> Bool {
        if let errorToThrow { throw errorToThrow }
        return toggleResult
    }
}

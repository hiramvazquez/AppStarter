import CoreNetworking
import Foundation

@testable import CartFeature

/// Doble de `CartLogicProtocol` con contador (M9): los tests del ViewModel no tocan red ni
/// `CartService`.
nonisolated final class CartLogicMock: CartLogicProtocol, @unchecked Sendable {
    var cartToReturn: Cart = .empty
    var errorToThrow: (any Error)?
    private(set) var loadCallCount = 0
    private(set) var lastUserId: Int?

    /// Si está puesto, `load` espera a que se cumpla antes de devolver. Recibe el número
    /// de llamada (1, 2, ...) para poder soltar UNA y dejar la otra en vuelo, que es lo
    /// que hace falta para observar qué le pasa a la fase cuando una carga supera a otra.
    var gate: (@Sendable (Int) async -> Void)?

    func load(userId: Int) async throws -> Cart {
        loadCallCount += 1
        let llamada = loadCallCount
        lastUserId = userId
        await gate?(llamada)
        if let errorToThrow { throw errorToThrow }
        return cartToReturn
    }
}

/// Doble de `CartServicing` para los tests de `CartLogic`.
nonisolated final class CartServiceMock: CartServicing, @unchecked Sendable {
    var result: Result<[Cart], APIError>
    private(set) var lastUserId: Int?

    init(result: Result<[Cart], APIError> = .success([])) {
        self.result = result
    }

    func fetchCarts(userId: Int) async throws(APIError) -> [Cart] {
        lastUserId = userId
        switch result {
        case .success(let carts): return carts
        case .failure(let error): throw error
        }
    }
}

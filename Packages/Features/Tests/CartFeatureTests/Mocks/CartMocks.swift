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

    // MARK: - Ediciones

    /// Lo que devuelven y lanzan las dos ediciones. Separado de la carga a propósito: un test de
    /// edición carga primero con éxito y luego hace fallar solo la edición.
    var editedCartToReturn: Cart = .empty
    var editErrorToThrow: (any Error)?
    /// Una llamada a `setQuantity`. Un `struct` y no una tupla: con tres miembros, la tupla es
    /// la que SwiftLint `--strict` rechaza (`large_tuple`). Los nombres son los mismos, así que
    /// los tests leen `.quantity`, `.lineId` y `.cart` igual que antes.
    struct SetQuantityCall {
        let quantity: Int
        let lineId: Int
        let cart: Cart
    }

    private(set) var setQuantityCalls: [SetQuantityCall] = []
    private(set) var removeLineCalls: [(lineId: Int, cart: Cart)] = []

    /// Como `gate`, para las ediciones: recibe el número de edición (1, 2, ...), contando las
    /// dos operaciones juntas. Deja una edición EN VUELO para observar el bloqueo.
    var editGate: (@Sendable (Int) async -> Void)?

    var editCallCount: Int { setQuantityCalls.count + removeLineCalls.count }

    func setQuantity(_ quantity: Int, ofLine lineId: Int, in cart: Cart) async throws -> Cart {
        setQuantityCalls.append(SetQuantityCall(quantity: quantity, lineId: lineId, cart: cart))
        return try await finishEdit()
    }

    func removeLine(_ lineId: Int, from cart: Cart) async throws -> Cart {
        removeLineCalls.append((lineId, cart))
        return try await finishEdit()
    }

    private func finishEdit() async throws -> Cart {
        await editGate?(editCallCount)
        if let editErrorToThrow { throw editErrorToThrow }
        return editedCartToReturn
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

/// Doble de `CartUpdateServicing` para los tests de `CartLogic`: guarda cada petición —a qué
/// carrito y con qué líneas—, que es lo que la `Logic` decide.
nonisolated final class CartUpdateServiceMock: CartUpdateServicing, @unchecked Sendable {
    /// Se puede cambiar entre llamadas, para simular la respuesta de cada edición.
    var result: Result<Cart, APIError>
    private(set) var calls: [(cartId: Int, lines: [CartLineQuantity])] = []

    init(result: Result<Cart, APIError> = .success(.empty)) {
        self.result = result
    }

    func replaceLines(cartId: Int, with lines: [CartLineQuantity]) async throws(APIError) -> Cart {
        calls.append((cartId, lines))
        switch result {
        case .success(let cart): return cart
        case .failure(let error): throw error
        }
    }
}

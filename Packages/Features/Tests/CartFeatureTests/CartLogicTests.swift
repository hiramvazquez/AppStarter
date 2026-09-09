import CoreNetworking
import Foundation
import Testing

@testable import CartFeature

/// `CartLogic` contra `CartServiceMock`: la reducción de la lista de carritos a uno, el
/// estado vacío, y el mapeo de `APIError` a `CartError` (M1).
@Suite("CartLogic")
struct CartLogicTests {
    private static func cart(lines: [CartLine] = [.fixture()]) -> Cart {
        Cart(lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
    }

    @Test("Devuelve el primer carrito del usuario")
    func returnsFirstCart() async throws {
        let first = Self.cart(lines: [.fixture(id: 1)])
        let second = Self.cart(lines: [.fixture(id: 2)])
        let service = CartServiceMock(result: .success([first, second]))

        let cart = try await CartLogic(cartService: service).load(userId: 3)

        #expect(cart == first)
        #expect(service.lastUserId == 3)
    }

    @Test("Un usuario sin carritos da el vacío, no un error")
    func noCartsGivesEmpty() async throws {
        let service = CartServiceMock(result: .success([]))

        let cart = try await CartLogic(cartService: service).load(userId: 1)

        #expect(cart.isEmpty)
        #expect(cart == .empty)
    }

    @Test("Sin conexión se traduce a .offline")
    func offlineMaps() async {
        let service = CartServiceMock(
            result: .failure(.stub(code: .transport, underlying: URLError(.notConnectedToInternet)))
        )

        await #expect(throws: CartError.offline) {
            try await CartLogic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un 404 se traduce a .notFound")
    func notFoundMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 404)))

        await #expect(throws: CartError.notFound) {
            try await CartLogic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un 503 se traduce a .server")
    func serverMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 503)))

        await #expect(throws: CartError.server) {
            try await CartLogic(cartService: service).load(userId: 1)
        }
    }

    @Test("Una cancelación se traduce a .cancelled, no a .unknown")
    func cancelledMaps() async {
        // Lo exige la spec `plataforma`: sin esta línea del `mapError`, la cancelación cae
        // en el `default` y la pantalla enseña "Algo salió mal" por algo que se canceló.
        let service = CartServiceMock(
            result: .failure(.stub(code: .cancelled, underlying: URLError(.cancelled)))
        )

        await #expect(throws: CartError.cancelled) {
            try await CartLogic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un error que no se distingue cae en .unknown")
    func unknownMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .decoding)))

        await #expect(throws: CartError.unknown) {
            try await CartLogic(cartService: service).load(userId: 1)
        }
    }
}

import CoreNetworking
import Foundation
import Testing

@testable import CartFeature

/// `CartLogic` contra `CartServiceMock` y `CartUpdateServiceMock`: la reducción de la lista de
/// carritos a uno, el estado vacío, la lista que manda cada edición, y el mapeo de `APIError` a
/// `CartError` (M1).
@Suite("CartLogic")
struct CartLogicTests {
    private static func cart(lines: [CartLine] = [.fixture()]) -> Cart {
        Cart(id: 1, lines: lines, total: 119.96, discountedTotal: 105.41, totalQuantity: 4)
    }

    private static func logic(
        cartService: CartServiceMock = CartServiceMock(),
        cartUpdateService: CartUpdateServiceMock = CartUpdateServiceMock()
    ) -> CartLogic {
        CartLogic(cartService: cartService, cartUpdateService: cartUpdateService)
    }

    @Test("Devuelve el primer carrito del usuario")
    func returnsFirstCart() async throws {
        let first = Self.cart(lines: [.fixture(id: 1)])
        let second = Self.cart(lines: [.fixture(id: 2)])
        let service = CartServiceMock(result: .success([first, second]))

        let cart = try await Self.logic(cartService: service).load(userId: 3)

        #expect(cart == first)
        #expect(service.lastUserId == 3)
    }

    @Test("Un usuario sin carritos da el vacío, no un error")
    func noCartsGivesEmpty() async throws {
        let service = CartServiceMock(result: .success([]))

        let cart = try await Self.logic(cartService: service).load(userId: 1)

        #expect(cart.isEmpty)
        #expect(cart == .empty)
    }

    @Test("Sin conexión se traduce a .offline")
    func offlineMaps() async {
        let service = CartServiceMock(
            result: .failure(.stub(code: .transport, underlying: URLError(.notConnectedToInternet)))
        )

        await #expect(throws: CartError.offline) {
            try await Self.logic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un 404 se traduce a .notFound")
    func notFoundMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 404)))

        await #expect(throws: CartError.notFound) {
            try await Self.logic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un 503 se traduce a .server")
    func serverMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 503)))

        await #expect(throws: CartError.server) {
            try await Self.logic(cartService: service).load(userId: 1)
        }
    }

    @Test("Una cancelación se traduce a .cancelled, no a .unknown")
    func cancelledMaps() async {
        // Lo exige la spec `plataforma`: sin esa línea de la traducción, la cancelación cae
        // en el `default` y la pantalla enseña "Algo salió mal" por algo que se canceló.
        // La traducción la hereda de `TransportMappable`, pero quien la comprueba es ESTA
        // feature: la cláusula 1 le aplica igual aunque el default venga de la plataforma.
        let service = CartServiceMock(
            result: .failure(.stub(code: .cancelled, underlying: URLError(.cancelled)))
        )

        await #expect(throws: CartError.cancelled) {
            try await Self.logic(cartService: service).load(userId: 1)
        }
    }

    @Test("Un error que no se distingue cae en .unknown")
    func unknownMaps() async {
        let service = CartServiceMock(result: .failure(.stub(code: .decoding)))

        await #expect(throws: CartError.unknown) {
            try await Self.logic(cartService: service).load(userId: 1)
        }
    }

    // MARK: - Ediciones

    /// Tres líneas con cantidades distintas, para que una lista mal compuesta —una línea
    /// perdida, una cantidad cambiada donde no toca, otro orden— se note.
    private static let tresLineas = Cart(
        id: 7,
        lines: [.fixture(id: 162, quantity: 4), .fixture(id: 113, quantity: 3), .fixture(id: 122, quantity: 1)],
        total: 100,
        discountedTotal: 90,
        totalQuantity: 8
    )

    /// Lo que «responde el servidor» en los tests que no miran su contenido: distinto de
    /// `tresLineas`, para que devolver el carrito de entrada en vez del de la respuesta se note.
    private static let respuesta = Cart(
        id: 7,
        lines: [.fixture(id: 999)],
        total: 1,
        discountedTotal: 1,
        totalQuantity: 1
    )

    @Test("Cambiar la cantidad manda TODAS las líneas, en orden, con esa cambiada, y devuelve la respuesta")
    func setQuantitySendsTheWholeList() async throws {
        let update = CartUpdateServiceMock(result: .success(Self.respuesta))

        let cart = try await Self.logic(cartUpdateService: update)
            .setQuantity(2, ofLine: 113, in: Self.tresLineas)

        #expect(update.calls.count == 1)
        #expect(update.calls.first?.cartId == 7)
        #expect(
            update.calls.first?.lines == [
                CartLineQuantity(id: 162, quantity: 4),
                CartLineQuantity(id: 113, quantity: 2),
                CartLineQuantity(id: 122, quantity: 1)
            ]
        )
        // Lo que se enseña es lo que dijo el servidor, no el carrito con la cantidad retocada.
        #expect(cart == Self.respuesta)
    }

    @Test("Quitar manda la lista sin esa línea, y devuelve la respuesta")
    func removeLineSendsTheListWithoutIt() async throws {
        let update = CartUpdateServiceMock(result: .success(Self.respuesta))

        let cart = try await Self.logic(cartUpdateService: update)
            .removeLine(113, from: Self.tresLineas)

        #expect(update.calls.first?.cartId == 7)
        #expect(
            update.calls.first?.lines == [
                CartLineQuantity(id: 162, quantity: 4),
                CartLineQuantity(id: 122, quantity: 1)
            ]
        )
        #expect(cart == Self.respuesta)
    }

    @Test("Una segunda edición sobre la respuesta de la primera no la deshace")
    func secondEditKeepsTheFirst() async throws {
        // El servidor no guarda: cada respuesta sale del carrito original. Lo único que hace
        // que la segunda edición conserve la primera es que la lista que manda salga del
        // carrito que YA la incluye.
        let trasCambiar = Cart(
            id: 7,
            lines: [.fixture(id: 162, quantity: 2), .fixture(id: 113, quantity: 3), .fixture(id: 122, quantity: 1)],
            total: 100,
            discountedTotal: 90,
            totalQuantity: 6
        )
        let update = CartUpdateServiceMock(result: .success(trasCambiar))
        let logic = Self.logic(cartUpdateService: update)

        let primera = try await logic.setQuantity(2, ofLine: 162, in: Self.tresLineas)
        update.result = .success(Self.respuesta)
        _ = try await logic.removeLine(122, from: primera)

        #expect(update.calls.count == 2)
        #expect(
            update.calls.last?.lines == [
                CartLineQuantity(id: 162, quantity: 2),
                CartLineQuantity(id: 113, quantity: 3)
            ]
        )
    }

    @Test("Una cantidad menor que 1 no llega al servidor y vuelve el mismo carrito")
    func quantityBelowOneNeverReachesTheServer() async throws {
        // La API acepta `quantity: 0` y deja la línea en el carrito, a cero.
        let update = CartUpdateServiceMock(result: .success(Self.respuesta))
        let logic = Self.logic(cartUpdateService: update)

        let conCero = try await logic.setQuantity(0, ofLine: 162, in: Self.tresLineas)
        let conNegativa = try await logic.setQuantity(-3, ofLine: 162, in: Self.tresLineas)

        #expect(update.calls.isEmpty)
        #expect(conCero == Self.tresLineas)
        #expect(conNegativa == Self.tresLineas)
    }

    @Test("Un carrito sin id —el de un usuario sin carritos— da .notFound sin llamar al servidor")
    func cartWithoutIdIsNotFound() async {
        let update = CartUpdateServiceMock(result: .success(Self.respuesta))
        let logic = Self.logic(cartUpdateService: update)

        await #expect(throws: CartError.notFound) {
            try await logic.setQuantity(2, ofLine: 1, in: .empty)
        }
        await #expect(throws: CartError.notFound) {
            try await logic.removeLine(1, from: .empty)
        }
        #expect(update.calls.isEmpty)
    }

    // MARK: - El fallo de una edición

    @Test("Una edición sin conexión se traduce a .offline")
    func editOfflineMaps() async {
        let update = CartUpdateServiceMock(
            result: .failure(.stub(code: .transport, underlying: URLError(.notConnectedToInternet)))
        )

        await #expect(throws: CartError.offline) {
            try await Self.logic(cartUpdateService: update).setQuantity(2, ofLine: 162, in: Self.tresLineas)
        }
    }

    @Test("Una edición con 404 se traduce a .notFound")
    func editNotFoundMaps() async {
        let update = CartUpdateServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 404)))

        await #expect(throws: CartError.notFound) {
            try await Self.logic(cartUpdateService: update).setQuantity(2, ofLine: 162, in: Self.tresLineas)
        }
    }

    @Test("Una edición con 503 se traduce a .server")
    func editServerMaps() async {
        let update = CartUpdateServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 503)))

        await #expect(throws: CartError.server) {
            try await Self.logic(cartUpdateService: update).setQuantity(2, ofLine: 162, in: Self.tresLineas)
        }
    }

    @Test("Una edición cancelada se traduce a .cancelled, no a .unknown")
    func editCancelledMaps() async {
        // Lo que permite al ViewModel reconocerla y no pintar error (spec `plataforma`).
        let update = CartUpdateServiceMock(
            result: .failure(.stub(code: .cancelled, underlying: URLError(.cancelled)))
        )

        await #expect(throws: CartError.cancelled) {
            try await Self.logic(cartUpdateService: update).setQuantity(2, ofLine: 162, in: Self.tresLineas)
        }
    }

    @Test("Una edición que no se puede decodificar cae en .unknown")
    func editDecodingMaps() async {
        // El riesgo que `design.md` nombra: que el servidor deje de mandar `discountedPrice`.
        let update = CartUpdateServiceMock(result: .failure(.stub(code: .decoding)))

        await #expect(throws: CartError.unknown) {
            try await Self.logic(cartUpdateService: update).setQuantity(2, ofLine: 162, in: Self.tresLineas)
        }
    }

    @Test("Quitar también traduce su fallo: comparte la frontera con cambiar la cantidad")
    func removeLineMapsItsFailureToo() async {
        let update = CartUpdateServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 503)))

        await #expect(throws: CartError.server) {
            try await Self.logic(cartUpdateService: update).removeLine(113, from: Self.tresLineas)
        }
    }
}

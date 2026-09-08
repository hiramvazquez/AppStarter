import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Testing

@testable import CartFeature

/// `CartService` — el único tipo de la feature que toca `APIServiceProtocol` — contra
/// `MockAPIService`.
@Suite("CartService")
struct CartServiceTests {
    @Test("Un 200 decodifica las líneas con su cantidad y su total con descuento")
    func decodesLines() async throws {
        let mock = MockAPIService()
        mock.stub(
            GetUserCartsRequest.self,
            returning: GetUserCartsRequest.Response(carts: [
                .init(
                    products: [
                        .init(
                            id: 162,
                            title: "Blue Frock",
                            price: 29.99,
                            quantity: 4,
                            discountedTotal: 105.41,
                            thumbnail: "https://cdn.dummyjson.com/thumb.webp"
                        )
                    ],
                    discountedTotal: 105.41,
                    totalQuantity: 4
                )
            ])
        )

        let carts = try await CartService(api: mock).fetchCarts(userId: 1)

        // El total del carrito, no solo el de la línea: es el número que la pantalla existe
        // para enseñar, y sin estas dos aserciones se podía poner a cero el mapeo entero y
        // los 23 tests seguían en verde. Lo cazó el revisor por mutación, no yo.
        #expect(carts.first?.discountedTotal == 105.41)
        #expect(carts.first?.totalQuantity == 4)

        let line = try #require(carts.first?.lines.first)
        #expect(line.id == 162)
        #expect(line.title == "Blue Frock")
        #expect(line.quantity == 4)
        #expect(line.discountedTotal == 105.41)
        #expect(line.unitPrice == 29.99)
        #expect(line.thumbnailURL == URL(string: "https://cdn.dummyjson.com/thumb.webp"))
    }

    @Test("Una línea sin miniatura decodifica con `thumbnailURL` nulo, no falla")
    func missingThumbnailDecodesToNil() async throws {
        let mock = MockAPIService()
        mock.stub(
            GetUserCartsRequest.self,
            returning: GetUserCartsRequest.Response(carts: [
                .init(
                    products: [
                        .init(id: 1, title: "x", price: 1, quantity: 1, discountedTotal: 1, thumbnail: nil)
                    ],
                    discountedTotal: 1,
                    totalQuantity: 1
                )
            ])
        )

        let carts = try await CartService(api: mock).fetchCarts(userId: 1)

        #expect(carts.first?.lines.first?.thumbnailURL == nil)
    }

    @Test("Una respuesta sin carritos devuelve lista vacía, no un error")
    func noCartsIsNotAnError() async throws {
        let mock = MockAPIService()
        mock.stub(GetUserCartsRequest.self, returning: GetUserCartsRequest.Response(carts: []))

        let carts = try await CartService(api: mock).fetchCarts(userId: 7)

        #expect(carts.isEmpty)
    }

    @Test("La ruta lleva el id del usuario que se pide")
    func pathCarriesTheUserId() {
        // Fija lo único que este request decide: sin esto, pedir el carrito de otro usuario
        // devolvería el mismo y ningún test lo notaría.
        #expect(GetUserCartsRequest(userId: 42).path == "/carts/user/42")
    }

    @Test("Un 503 llega como error de servidor, sin tocarlo")
    func serverErrorSurfaces() async {
        let mock = MockAPIService()
        mock.stub(GetUserCartsRequest.self, throwing: .stub(code: .httpStatus, statusCode: 503))

        await #expect(throws: APIError.self) {
            try await CartService(api: mock).fetchCarts(userId: 1)
        }
    }
}

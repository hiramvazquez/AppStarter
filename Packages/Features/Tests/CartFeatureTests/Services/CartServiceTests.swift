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
                            total: 119.96,
                            discountedTotal: 105.41,
                            thumbnail: "https://cdn.dummyjson.com/thumb.webp"
                        )
                    ],
                    total: 119.96,
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
        // El importe SIN descuento, en los dos niveles. Es el campo que la respuesta traía
        // y la app tiraba: sin estas dos, se puede mapear a cero y la pantalla vuelve a no
        // poder explicar de dónde sale la rebaja, con todo en verde.
        #expect(carts.first?.total == 119.96)

        let line = try #require(carts.first?.lines.first)
        #expect(line.id == 162)
        #expect(line.title == "Blue Frock")
        #expect(line.quantity == 4)
        #expect(line.discountedTotal == 105.41)
        #expect(line.total == 119.96)
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
                        .init(
                            id: 1, title: "x", price: 1, quantity: 1,
                            total: 1, discountedTotal: 1, thumbnail: nil
                        )
                    ],
                    total: 1,
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

    @Test("El JSON real de la API decodifica `total`: la clave del wire, no solo el mapeo")
    func decodesTotalFromActualJSON() async throws {
        // `MockAPIService.stub(_:returning:)` recibe un `Response` YA CONSTRUIDO en Swift, así
        // que `JSONDecoder` no interviene en ninguno de los tests de arriba pese a lo que
        // sugieren sus nombres. Eso deja sin cubrir la clave del wire: con un `CodingKeys`
        // equivocado —o el campo escrito `subtotal`— todos seguirían verdes y la app fallaría
        // en cada carga. Este pasa bytes de verdad, copiados de la respuesta real de
        // `GET /carts/user/1`.
        let transport = InMemoryTransport()
        let cuerpo = Data("""
            {"carts":[{"id":1,"products":[
              {"id":162,"title":"Blue Frock","price":29.99,"quantity":4,
               "total":119.96,"discountPercentage":12.13,"discountedTotal":105.41,
               "thumbnail":"https://cdn.dummyjson.com/thumb.webp"}],
              "total":119.96,"discountedTotal":105.41,
              "userId":1,"totalProducts":1,"totalQuantity":4}],
             "total":1,"skip":0,"limit":1}
            """.utf8)
        await transport.register(
            InMemoryTransport.Exchange(
                method: .get,
                url: URL(string: "https://example.test/carts/user/1")!,
                response: .response(status: 200, body: cuerpo)
            )
        )
        let api = APIService(
            configuration: NetworkingConfiguration(baseURL: URL(string: "https://example.test")!),
            transport: transport
        )

        let carts = try await CartService(api: api).fetchCarts(userId: 1)

        let line = try #require(carts.first?.lines.first)
        #expect(line.total == 119.96)
        #expect(carts.first?.total == 119.96)
        // Y que sigue leyendo bien lo de siempre, para que este test no tape una regresión
        // en el resto del mapeo mientras solo mira el campo nuevo.
        #expect(line.discountedTotal == 105.41)
        #expect(line.quantity == 4)
        #expect(carts.first?.totalQuantity == 4)
        // La rebaja, extremo a extremo: del JSON a la decisión que toma la pantalla.
        #expect(line.hasDiscount)
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

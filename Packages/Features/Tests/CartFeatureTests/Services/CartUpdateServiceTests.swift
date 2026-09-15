import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Testing

@testable import CartFeature

/// `CartUpdateService` contra `InMemoryTransport`, con bytes de verdad en los dos sentidos.
///
/// Lo que este servicio decide es el WIRE —el cuerpo que manda y las claves que lee—, y un
/// `MockAPIService` con un `Response` construido en Swift no pasa ni por `JSONEncoder` ni por
/// `JSONDecoder`: con `discountedTotal` escrito donde el servidor manda `discountedPrice`, un
/// test así seguiría verde y cada edición fallaría en la app.
@Suite("CartUpdateService")
struct CartUpdateServiceTests {
    /// La respuesta real de `PUT https://dummyjson.com/carts/1` con
    /// `{"merge":false,"products":[{"id":162,"quantity":2},{"id":113,"quantity":3},{"id":122,"quantity":3}]}`,
    /// medida el 2026-09-15. Solo se han acortado las URL de las miniaturas.
    private static let respuestaReal = Data("""
        {"id":1,"products":[
          {"id":162,"title":"Blue Frock","price":29.99,"quantity":2,"total":59.98,
           "discountPercentage":12.13,"discountedPrice":53,
           "thumbnail":"https://cdn.dummyjson.com/thumb.webp"},
          {"id":113,"title":"Generic Motorcycle","price":3999.99,"quantity":3,"total":11999.97,
           "discountPercentage":12.1,"discountedPrice":10548,
           "thumbnail":"https://cdn.dummyjson.com/thumb.webp"},
          {"id":122,"title":"iPhone 6","price":299.99,"quantity":3,"total":899.97,
           "discountPercentage":6.69,"discountedPrice":840,
           "thumbnail":"https://cdn.dummyjson.com/thumb.webp"}],
         "total":12959.919999999998,"discountedTotal":11441,
         "userId":1,"totalProducts":3,"totalQuantity":8}
        """.utf8)

    /// Las líneas que produjeron `respuestaReal`, en el orden en que se mandaron.
    private static let lineas = [
        CartLineQuantity(id: 162, quantity: 2),
        CartLineQuantity(id: 113, quantity: 3),
        CartLineQuantity(id: 122, quantity: 3),
    ]

    private static func servicio(
        status: Int = 200,
        cuerpo: Data = respuestaReal
    ) async -> (CartUpdateService, InMemoryTransport) {
        let transport = InMemoryTransport()
        await transport.register(
            InMemoryTransport.Exchange(
                method: .put,
                url: URL(string: "https://example.test/carts/1")!,
                response: .response(status: status, body: cuerpo)
            )
        )
        let api = APIService(
            configuration: NetworkingConfiguration(baseURL: URL(string: "https://example.test")!),
            transport: transport
        )
        return (CartUpdateService(api: api), transport)
    }

    @Test("Es un PUT a /carts/{id} del carrito que se edita")
    func putsToTheCartPath() async throws {
        let (servicio, transport) = await Self.servicio()

        _ = try await servicio.replaceLines(cartId: 1, with: Self.lineas)

        let enviada = try #require(await transport.recorded.first)
        #expect(enviada.httpMethod == "PUT")
        #expect(enviada.url?.path == "/carts/1")
        // La ruta sale del id que se pasa, no de una constante: con otro carrito, otra ruta.
        #expect(UpdateCartRequest(cartId: 42, lines: []).path == "/carts/42")
    }

    @Test("El cuerpo sustituye —`merge` a `false` como booleano— y lleva las líneas en orden")
    func bodyReplacesWithEveryLineInOrder() async throws {
        let (servicio, transport) = await Self.servicio()

        _ = try await servicio.replaceLines(cartId: 1, with: Self.lineas)

        let cuerpo = try #require(await transport.recorded.first?.httpBody)
        // Sobre el texto, no decodificando: `"merge":"false"` (string, que el servidor tomaría
        // por verdadero) y `"merge":0` fallarían este `contains`, y con `true` volverían las
        // líneas quitadas.
        let texto = try #require(String(data: cuerpo, encoding: .utf8))
        #expect(texto.contains(#""merge":false"#))

        struct Enviado: Decodable {
            struct Linea: Decodable, Equatable {
                let id: Int
                let quantity: Int
            }
            let products: [Linea]
        }
        let enviado = try JSONDecoder().decode(Enviado.self, from: cuerpo)
        #expect(enviado.products == [.init(id: 162, quantity: 2), .init(id: 113, quantity: 3), .init(id: 122, quantity: 3)])
    }

    @Test("La respuesta real llega al carrito: `discountedPrice` es el importe con descuento de la línea")
    func mapsTheRealResponse() async throws {
        let (servicio, _) = await Self.servicio()

        let cart = try await servicio.replaceLines(cartId: 1, with: Self.lineas)

        #expect(cart.id == 1)
        #expect(cart.lines.map(\.id) == [162, 113, 122])
        #expect(cart.lines.map(\.quantity) == [2, 3, 3])
        // El campo que NO se llama igual que en el `GET`. Redondeado a unidades por el
        // servidor, y así se enseña: manda la API.
        #expect(cart.lines.map(\.discountedTotal) == [53, 10548, 840])
        #expect(cart.lines.first?.total == 59.98)
        #expect(cart.lines.first?.unitPrice == 29.99)
        #expect(cart.lines.first?.title == "Blue Frock")
        #expect(cart.lines.first?.thumbnailURL == URL(string: "https://cdn.dummyjson.com/thumb.webp"))
        #expect(cart.total == 12959.919999999998)
        #expect(cart.discountedTotal == 11441)
        #expect(cart.totalQuantity == 8)
    }

    @Test("Quitar la última línea responde un carrito vacío con su id, no un error")
    func emptyProductsIsAnEmptyCart() async throws {
        // Medido el 2026-09-15: `PUT /carts/1` con `"products":[]` responde 200 con esto.
        let (servicio, _) = await Self.servicio(cuerpo: Data("""
            {"id":1,"products":[],"total":0,"discountedTotal":0,"userId":1,"totalProducts":0,"totalQuantity":0}
            """.utf8))

        let cart = try await servicio.replaceLines(cartId: 1, with: [])

        #expect(cart.isEmpty)
        #expect(cart.id == 1)
    }

    @Test("Un 404 llega como `APIError`, sin tocarlo")
    func notFoundSurfaces() async {
        // El cuerpo es el que manda el servidor real para un carrito que no existe.
        let (servicio, _) = await Self.servicio(
            status: 404,
            cuerpo: Data(#"{"message":"Cart with id '1' not found"}"#.utf8)
        )

        await #expect(throws: APIError.self) {
            try await servicio.replaceLines(cartId: 1, with: Self.lineas)
        }
    }
}

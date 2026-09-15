import CoreNetworking
import Foundation

// MARK: - The request / response DTOs (M2: only this file ever sees them)

/// `PUT /carts/{id}` de DummyJSON: SUSTITUYE las líneas del carrito por las que se mandan y
/// devuelve el carrito recalculado por el servidor.
///
/// DTO propio y no el de `GetUserCartsRequest`, porque el wire NO coincide. Medido contra el
/// servidor real el 2026-09-15: el importe con descuento de cada línea llega como
/// `discountedPrice`, redondeado a unidades (`53`), donde el `GET` manda `discountedTotal` con
/// céntimos (`105.41`). Un DTO compartido obligaría a hacer opcionales los dos campos, y uno al
/// que le faltaran ambos degradaría en silencio — lo que `GetUserCartsRequest.LineDTO.total`
/// documenta que no se hace.
struct UpdateCartRequest: BaseRequest {
    struct Body: Encodable, Sendable {
        /// SIEMPRE `false`, y escrito aunque sea el default del servidor. Con `true` el servidor
        /// fusiona con el carrito original —lo único que recuerda: no guarda ediciones— y las
        /// líneas quitadas volverían. Y va como `Bool` a propósito: el servidor evalúa
        /// `if (merge)`, así que un `"false"` en string contaría como verdadero.
        let merge: Bool
        let products: [LineQuantityDTO]
    }

    struct LineQuantityDTO: Encodable, Sendable {
        let id: Int
        let quantity: Int
    }

    struct LineDTO: Decodable, Sendable {
        let id: Int
        let title: String
        let price: Double
        let quantity: Int
        let total: Double
        /// El importe de la línea ENTERA con el descuento aplicado, redondeado a unidades por el
        /// servidor. No es un precio unitario, pese al nombre: `2 × 29.99` al 12,13 % llega como
        /// `53`. Es lo que el `GET` llama `discountedTotal`, y va a `CartLine.discountedTotal`.
        /// No opcional, por la misma razón que `total`.
        let discountedPrice: Double
        let thumbnail: String?
    }

    struct Response: Decodable, Sendable {
        let id: Int
        let products: [LineDTO]
        let total: Double
        let discountedTotal: Double
        let totalQuantity: Int
    }

    let cartId: Int
    var path: String { "/carts/\(cartId)" }
    let method = HTTPMethod.put
    let body: Body?

    init(cartId: Int, lines: [CartLineQuantity]) {
        self.cartId = cartId
        self.body = Body(
            merge: false,
            products: lines.map { LineQuantityDTO(id: $0.id, quantity: $0.quantity) }
        )
    }
}

// MARK: - The service

/// Una línea tal y como la pide una edición: qué producto y cuántas unidades. Es lo que
/// `CartLogic` compone y `CartUpdateServicing` recibe — nunca el DTO (M2).
public nonisolated struct CartLineQuantity: Sendable, Equatable {
    public let id: Int
    public let quantity: Int

    public init(id: Int, quantity: Int) {
        self.id = id
        self.quantity = quantity
    }
}

/// La llamada que edita el carrito. Un Service por llamada a API (`AGENTS.md`): por eso no es un
/// método más de `CartService`. `CartLogic` lo conoce por su `init`, nunca como tipo concreto.
public protocol CartUpdateServicing: Sendable {
    /// Sustituye TODAS las líneas del carrito `cartId` por `lines`, en ese orden, y devuelve el
    /// carrito que calcula el servidor. Una lista vacía es válida: deja el carrito sin líneas.
    ///
    /// Se manda la lista entera y no solo lo que cambia porque el servidor no guarda nada: cada
    /// respuesta sale del carrito original, así que una petición parcial desharía las ediciones
    /// anteriores de la pantalla.
    func replaceLines(cartId: Int, with lines: [CartLineQuantity]) async throws(APIError) -> Cart
}

/// El único tipo que referencia `UpdateCartRequest`. Conforma `EndpointService` para tener
/// `call(_:)` gratis.
public struct CartUpdateService: CartUpdateServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func replaceLines(cartId: Int, with lines: [CartLineQuantity]) async throws(APIError) -> Cart {
        let dto = try await call(UpdateCartRequest(cartId: cartId, lines: lines))
        return Cart(
            id: dto.id,
            lines: dto.products.map { line in
                CartLine(
                    id: line.id,
                    title: line.title,
                    unitPrice: line.price,
                    quantity: line.quantity,
                    total: line.total,
                    discountedTotal: line.discountedPrice,
                    thumbnailURL: line.thumbnail.flatMap(URL.init(string:))
                )
            },
            total: dto.total,
            discountedTotal: dto.discountedTotal,
            totalQuantity: dto.totalQuantity
        )
    }
}

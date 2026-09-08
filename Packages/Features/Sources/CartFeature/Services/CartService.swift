import CoreNetworking
import Foundation

// MARK: - The request / response DTOs (M2: only this file ever sees them)

/// `GET /carts/user/{id}` de DummyJSON: los carritos de un usuario, con sus líneas ya
/// calculadas por el servidor (cantidad, total y total con descuento por línea).
///
/// Los DTO se quedan en este fichero y no se comparten con ninguna otra feature (M2),
/// aunque `ProductDTO` se parezca al de `ProductsService`: son respuestas de endpoints
/// distintos y evolucionan por separado. La duplicación aparente es deliberada; lo que no
/// se duplica es el MODELO, que es `CartLine`.
struct GetUserCartsRequest: BaseRequest {
    struct LineDTO: Decodable, Sendable {
        let id: Int
        let title: String
        let price: Double
        let quantity: Int
        let discountedTotal: Double
        /// Ausente en fixtures hechos a mano — se decodifica como `nil` en vez de fallar.
        let thumbnail: String?
    }

    struct CartDTO: Decodable, Sendable {
        let products: [LineDTO]
        let discountedTotal: Double
        let totalQuantity: Int
    }

    struct Response: Decodable, Sendable {
        let carts: [CartDTO]
    }

    let userId: Int
    var path: String { "/carts/user/\(userId)" }
    let method = HTTPMethod.get

    init(userId: Int) {
        self.userId = userId
    }
}

// MARK: - The service

/// La única llamada a red de esta feature. `CartServicing` es lo que `CartLogic` conoce a
/// través de su `init` — nunca este tipo concreto.
public protocol CartServicing: Sendable {
    /// Los carritos del usuario, en el orden en que los devuelve la API. Una lista vacía es
    /// una respuesta válida —un usuario sin carritos—, no un error.
    func fetchCarts(userId: Int) async throws(APIError) -> [Cart]
}

/// El ÚNICO tipo de esta feature que referencia `APIServiceProtocol`/`BaseRequest`.
/// Conforma `EndpointService` (CoreNetworking) para tener `call(_:)` gratis.
public struct CartService: CartServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func fetchCarts(userId: Int) async throws(APIError) -> [Cart] {
        let response = try await call(GetUserCartsRequest(userId: userId))
        return response.carts.map { dto in
            Cart(
                lines: dto.products.map { line in
                    CartLine(
                        id: line.id,
                        title: line.title,
                        unitPrice: line.price,
                        quantity: line.quantity,
                        discountedTotal: line.discountedTotal,
                        thumbnailURL: line.thumbnail.flatMap(URL.init(string:))
                    )
                },
                discountedTotal: dto.discountedTotal,
                totalQuantity: dto.totalQuantity
            )
        }
    }
}

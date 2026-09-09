import AppFoundation
import CoreNetworking
import Domain
import Foundation

// MARK: - The domain model

/// Los céntimos con los que este importe SE VA A PINTAR.
///
/// Se redondea sobre la representación decimal corta del doble (`"\(amount)"`) y con
/// half-even, porque es lo que hace `.currency(...)`. La versión obvia —`(x * 100).rounded()`—
/// no sirve: multiplicar por 100 en binario mete el error ANTES de redondear, y por ahí se
/// colaban pares que la pantalla pinta idénticos y el modelo daba por distintos
/// (`1620.125` contra `1620.12`: los dos son `US$1,620.12`, y la fila tachaba un importe
/// igual al de abajo). Medido sobre 240 000 pares contra el string del formateador: 1
/// desacuerdo, y es `US$0.00` contra `-US$0.00`.
///
/// `nonisolated` como los dos tipos que la llaman (M5): sin ello el módulo la aísla al actor
/// principal por defecto y `CartLine`/`Cart`, que no lo están, no pueden invocarla.
/// `nil` cuando el importe no cabe en un `Decimal` — desde ~`1e128`, y `JSONDecoder` acepta
/// hasta `1e400`. NO se cae a `Decimal(amount)`: ese fallback no protegía de nada. Con un
/// doble fuera de rango daba NaN, y `NaN < finito` es `true` en `Decimal` (al revés que en
/// IEEE), así que resucitaba justo el recargo-pintado-como-rebaja que `isDiscount` existe
/// para impedir; y con infinito, `Decimal(Double.infinity)` directamente trapea. Devolver
/// `nil` deja que quien compara decida, y decide no decorar.
private nonisolated func centsOnScreen(_ amount: Double) -> Decimal? {
    guard var value = Decimal(string: "\(amount)") else { return nil }
    var rounded = Decimal()
    NSDecimalRound(&rounded, &value, 2, .bankers)
    return rounded
}

/// ¿Pagar `discountedTotal` en vez de `total` es, en pantalla, una REBAJA?
///
/// Una sola implementación para la línea y para el carrito. Es la frontera que fija la
/// cláusula 3 del requisito `carrito` («la rebaja que se aplica se ve, y cuando no la hay no
/// se inventa»), y escrita dos veces serían dos sitios que pueden discrepar.
///
/// DIRECCIONAL a propósito, no una comparación simétrica de «difieren». Con `<` en vez de
/// `!=`, un importe que SUBE deja de contar: si `discountedTotal` fuera mayor que `total`
/// —un recargo—, la simetría hacía que la fila tachara el importe menor encima del mayor y
/// que el pie escribiera «Descuento −-US$5.00», con el signo del formateador pegado al
/// nuestro. Un recargo presentado con la decoración de una rebaja dice lo contrario de lo que
/// pasa, y esta pantalla no tiene diseño para enseñarlo: no lo decora, y punto.
private nonisolated func isDiscount(from total: Double, to discountedTotal: Double) -> Bool {
    // Un importe que no se puede pasar a céntimos tampoco se puede enseñar tachado con
    // sentido: no se decora. Es la misma respuesta que para «coinciden» y para «sube».
    guard let pagado = centsOnScreen(discountedTotal), let antes = centsOnScreen(total) else {
        return false
    }
    return pagado < antes
}

/// Una línea del carrito: un producto, cuántas unidades y lo que suma con el descuento ya
/// aplicado. `Sendable`/`Equatable` — nunca el DTO (M2), ver `Services/CartService.swift`.
///
/// NO reutiliza `Domain.Product` a propósito. Se parece —`id`, `title`, `price`,
/// `thumbnailURL`— pero `GET /carts/user/{id}` no devuelve `description`, `rating` ni
/// `images`, que `Product` exige, y en cambio devuelve `quantity` y `discountedTotal`, que
/// `Product` no tiene. Encajar una en otra obligaría a inventar datos, o a hacer opcional
/// media `Product` para todas las demás pantallas.
///
/// Y se queda en esta feature, sin subir a `Domain`: la usa una sola pantalla. Traer algo a
/// la capa compartida con un único consumidor convierte una decisión local en superficie
/// para nadie — la misma razón que documenta `ErrorCopy`.
public nonisolated struct CartLine: Sendable, Equatable, Hashable, Identifiable {
    /// El id del producto. Un producto no se repite dentro de un carrito: las unidades van
    /// en `quantity`, no en líneas repetidas.
    public let id: Int
    public let title: String
    /// Precio unitario SIN descuento. La pantalla lo enseña junto al total real; no es lo
    /// que se paga.
    public let unitPrice: Double
    public let quantity: Int
    /// Lo que suma esta línea SIN descuento, tal y como lo devuelve la API. No se calcula
    /// como `Double(quantity) * unitPrice`: es la misma regla que ya gobierna
    /// `discountedTotal` —manda la API, que es quien cobra— aplicada al otro extremo de la
    /// resta. Presentar un «antes» que el servidor no ha dicho es inventarse el número del
    /// que se deriva la rebaja.
    public let total: Double
    /// Lo que suma esta línea CON el descuento aplicado. Es la cifra que importa: un
    /// carrito que enseña precios unitarios sueltos no dice lo que se va a pagar.
    public let discountedTotal: Double
    public let thumbnailURL: URL?

    public init(
        id: Int,
        title: String,
        unitPrice: Double,
        quantity: Int,
        total: Double,
        discountedTotal: Double,
        thumbnailURL: URL?
    ) {
        self.id = id
        self.title = title
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.total = total
        self.discountedTotal = discountedTotal
        self.thumbnailURL = thumbnailURL
    }

    /// Lo que esta línea se ahorra. EN CRUDO, sin cortar a céntimos: lo consume el
    /// formateador de moneda, que ya redondea (`14.549999… → 14,55 $`).
    ///
    /// Y no decide nada. Quien responde «¿hay rebaja?» es `hasDiscount`, y solo él: si esto
    /// también la respondiera devolviendo cero, habría dos sitios contestando lo mismo que
    /// podrían discrepar. El `-0.0001` que devuelve para una diferencia por debajo del
    /// céntimo es inalcanzable en pantalla — para llegar a pintarse, `hasDiscount` ya habría
    /// dicho que no hay nada que pintar.
    public var discountAmount: Double { total - discountedTotal }

    /// Si esta línea lleva rebaja que el usuario pueda ver. Ver `isDiscount(from:to:)`.
    public var hasDiscount: Bool { isDiscount(from: total, to: discountedTotal) }
}

/// Lo que `CartView` pinta: las líneas y lo que suman.
///
/// `GET /carts/user/{id}` devuelve una LISTA de carritos. Esta pantalla muestra el primero;
/// esa reducción se hace en la `Logic`, no aquí — ver `CartLogic.load(userId:)`.
public nonisolated struct Cart: Sendable, Equatable {
    public let lines: [CartLine]
    /// Total SIN descuento, tal y como lo devuelve la API. Tampoco se recalcula sumando las
    /// líneas, por la misma razón que `discountedTotal`.
    public let total: Double
    /// Total con descuento, tal y como lo devuelve la API. No se recalcula sumando las
    /// líneas: si la API y la suma discreparan, manda la API, que es quien cobra.
    public let discountedTotal: Double
    public let totalQuantity: Int

    public init(lines: [CartLine], total: Double, discountedTotal: Double, totalQuantity: Int) {
        self.lines = lines
        self.total = total
        self.discountedTotal = discountedTotal
        self.totalQuantity = totalQuantity
    }

    /// Un usuario sin carritos. Distinto de "falló": la pantalla tiene estado vacío propio.
    public static let empty = Cart(lines: [], total: 0, discountedTotal: 0, totalQuantity: 0)

    public var isEmpty: Bool { lines.isEmpty }

    /// Lo que el carrito entero se ahorra. En crudo, por la misma razón que
    /// `CartLine.discountAmount`.
    public var discountAmount: Double { total - discountedTotal }

    /// Si el carrito lleva rebaja que el usuario pueda ver. Ver `isDiscount(from:to:)`.
    public var hasDiscount: Bool { isDiscount(from: total, to: discountedTotal) }
}

// MARK: - Domain errors (M1)

/// Cada forma en la que puede fallar esta pantalla — nunca `APIError`, que se queda en la
/// frontera Logic/Service.
public enum CartError: DomainError, Equatable {
    case offline
    case notFound
    case server
    /// La carga se canceló. Existe porque la spec `plataforma` lo exige de toda feature que
    /// lance una cancelación venida de la red: se mapea desde `APIError.Category.cancelled`
    /// en vez de caer en `.unknown`, no es reintentable, y `AppCancellationRecognizer` lo
    /// reconoce para que `BaseViewModel` no lo presente como error.
    case cancelled
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .notFound, .cancelled: false
        case .offline, .server, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .notFound:
            return ScreenError(title: "Sin carrito", message: "No encontramos el carrito de esta cuenta.")
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        case .cancelled:
            return ScreenError(title: "Cancelado", message: "La operación se canceló.")
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        }
    }
}

// MARK: - Logic

/// Cada operación que `CartViewModel` puede pedirle a su Logic.
public protocol CartLogicProtocol: Logic {
    func load(userId: Int) async throws -> Cart
}

/// Toda la lógica de negocio de esta feature: una llamada a `CartServicing`, la reducción
/// de la lista de carritos a uno, y el mapeo del fallo a `CartError`.
///
/// `nonisolated` (M5): no depende del actor principal.
public nonisolated final class CartLogic: CartLogicProtocol {
    private let cartService: any CartServicing

    public init(cartService: any CartServicing) {
        self.cartService = cartService
    }

    public func load(userId: Int) async throws -> Cart {
        do {
            let carts = try await cartService.fetchCarts(userId: userId)
            // Sin carritos NO es un error: es el estado vacío de la pantalla. Devolver
            // `.empty` en vez de lanzar es lo que permite distinguirlo de un fallo.
            return carts.first ?? .empty
        } catch {
            // `fetchCarts` es `throws(APIError)`: aquí `error` ya es `APIError`.
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> CartError {
        switch error.category {
        case .offline: return .offline
        case .notFound: return .notFound
        case .server: return .server
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

import AppFoundation
import CoreNetworking
import Domain
import Foundation

// MARK: - The domain model

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
    /// Lo que suma esta línea CON el descuento aplicado. Es la cifra que importa: un
    /// carrito que enseña precios unitarios sueltos no dice lo que se va a pagar.
    public let discountedTotal: Double
    public let thumbnailURL: URL?

    public init(
        id: Int,
        title: String,
        unitPrice: Double,
        quantity: Int,
        discountedTotal: Double,
        thumbnailURL: URL?
    ) {
        self.id = id
        self.title = title
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.discountedTotal = discountedTotal
        self.thumbnailURL = thumbnailURL
    }
}

/// Lo que `CartView` pinta: las líneas y lo que suman.
///
/// `GET /carts/user/{id}` devuelve una LISTA de carritos. Esta pantalla muestra el primero;
/// esa reducción se hace en la `Logic`, no aquí — ver `CartLogic.load(userId:)`.
public nonisolated struct Cart: Sendable, Equatable {
    public let lines: [CartLine]
    /// Total con descuento, tal y como lo devuelve la API. No se recalcula sumando las
    /// líneas: si la API y la suma discreparan, manda la API, que es quien cobra.
    public let discountedTotal: Double
    public let totalQuantity: Int

    public init(lines: [CartLine], discountedTotal: Double, totalQuantity: Int) {
        self.lines = lines
        self.discountedTotal = discountedTotal
        self.totalQuantity = totalQuantity
    }

    /// Un usuario sin carritos. Distinto de "falló": la pantalla tiene estado vacío propio.
    public static let empty = Cart(lines: [], discountedTotal: 0, totalQuantity: 0)

    public var isEmpty: Bool { lines.isEmpty }
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

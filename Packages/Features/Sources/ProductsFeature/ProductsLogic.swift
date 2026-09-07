import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - Domain errors (M1)

public enum ProductsError: DomainError, Equatable {
    case offline
    case server
    case cancelled
    case unknown

    /// `.cancelled` NO es reintentable: un botón de «Reintentar» sobre algo que se acaba
    /// de cancelar invita a deshacer esa decisión. Mismo criterio que `DiagnosticsError`.
    public var isRetryable: Bool {
        switch self {
        case .cancelled: false
        case .offline, .server, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        // Este arm NO debería renderizarse nunca: `AppCancellationRecognizer` intercepta
        // el caso antes de que `BaseViewModel` llame a `setError`. Existe porque el
        // `switch` es exhaustivo, y devuelve el texto genérico A PROPÓSITO — inventar copy
        // propia aquí sería escribir un mensaje para una pantalla que no debe aparecer, y
        // haría creer al siguiente que este camino es normal. Lo que mantiene el arm
        // inalcanzable es el test del recognizer, no este comentario.
        case .cancelled:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        }
    }
}

// MARK: - Logic

/// The paginated-list contract `ProductsViewModel` sequences: `loadPage(skip:)` for both
/// the first page (`skip: 0`) and every subsequent one (pull-to-refresh calls it again
/// with `skip: 0`, "load more" with the next offset) — a single call, not two, since
/// DummyJSON's `/products` has no separate cache to fall back on the way
/// `CatalogApp`'s local store does (this feature has no `--local` half).
public protocol ProductsLogicProtocol: Logic {
    /// Fixed page size every call uses.
    var pageSize: Int { get }

    func loadPage(skip: Int) async throws -> ProductsPage
}

/// ALL of the Products feature's business logic: one call to `ProductsServicing`
/// (`Networking`), mapped to `ProductsError` on failure.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class ProductsLogic: ProductsLogicProtocol {
    public let pageSize = 20

    private let productsService: any ProductsServicing

    public init(productsService: any ProductsServicing) {
        self.productsService = productsService
    }

    public func loadPage(skip: Int) async throws -> ProductsPage {
        do {
            return try await productsService.fetchProducts(limit: pageSize, skip: skip)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> ProductsError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

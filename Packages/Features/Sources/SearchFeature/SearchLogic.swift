import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - Domain errors (M1)

public enum SearchError: DomainError, Equatable {
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

/// Every operation `SearchViewModel` can ask its `Logic` for.
public protocol SearchLogicProtocol: Logic {
    func search(query: String) async throws -> [Product]
}

/// ALL of the Search feature's business logic: one call to `ProductsServicing`
/// (`Networking` — shared with `Products`/`ProductDetail`), mapped to `SearchError` on
/// failure.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class SearchLogic: SearchLogicProtocol {
    private let productsService: any ProductsServicing

    public init(productsService: any ProductsServicing) {
        self.productsService = productsService
    }

    public func search(query: String) async throws -> [Product] {
        do {
            return try await productsService.search(query: query)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> SearchError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

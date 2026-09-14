import AppFoundation
import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - The domain model

/// What `GalleryView` renders: the product's title (bar/share context) and its images.
/// `Sendable`/`Equatable` — never the DTO (M2), see `Services/GalleryService.swift`.
public nonisolated struct GalleryState: Sendable, Equatable {
    public let title: String
    public let images: [URL]

    public init(title: String, images: [URL]) {
        self.title = title
        self.images = images
    }
}

// MARK: - Domain errors (M1)

public enum GalleryError: TransportMappable {
    case offline
    case notFound
    case server
    /// La carga se canceló. Existe porque la spec `plataforma` lo exige de toda feature que
    /// lance una cancelación venida de la red: se mapea desde `APIError.Category.cancelled`
    /// en vez de caer en `.unknown`, no es reintentable, y `AppCancellationRecognizer` lo
    /// reconoce para que `BaseViewModel` no lo presente como error.
    ///
    /// Sin este caso, cancelar una carga pintaba un error a pantalla completa con
    /// «Reintentar» — sobre algo que el usuario acababa de cancelar.
    case cancelled
    case unknown

    // `isRetryable` y la traducción desde `APIError` las da `TransportMappable` (`Networking`):
    // estaban escritas igual en tres features. El `screenError` sí se queda aquí.
    //
    // OJO AL AÑADIR UN CASO: `isRetryable` se hereda por EXCLUSIÓN —todo lo que no sea `.notFound`
    // ni `.cancelled` es reintentable—, así que un caso nuevo será reintentable SIN que el
    // compilador te pregunte. Antes lo forzaba un `switch` exhaustivo; ahora lo decides tú aquí.

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .notFound:
            return ScreenError(title: ErrorCopy.NotFound.title, message: ErrorCopy.NotFound.message)
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        // No debería renderizarse: `AppCancellationRecognizer` intercepta el caso antes de que
        // `BaseViewModel` llame a `setError`. Está porque el `switch` es exhaustivo.
        case .cancelled:
            return ScreenError(title: ErrorCopy.Cancelled.title, message: ErrorCopy.Cancelled.message)
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
        }
    }
}

// MARK: - Logic

/// Every operation `GalleryViewModel` can ask its `Logic` for.
public protocol GalleryLogicProtocol: Logic {
    func load(productID: Int) async throws -> GalleryState

    /// Never throws — a failed prefetch degrades to "not cached yet", not an error the
    /// screen shows (see `GalleryServicing.prefetchImage(url:)`).
    func prefetchImage(url: URL) async
}

/// ALL of the Gallery feature's business logic: one call to `GalleryServicing`, mapped to
/// `GalleryError` on failure.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class GalleryLogic: GalleryLogicProtocol {
    private let galleryService: any GalleryServicing

    public init(galleryService: any GalleryServicing) {
        self.galleryService = galleryService
    }

    public func load(productID: Int) async throws -> GalleryState {
        do {
            let product = try await galleryService.fetchProduct(id: productID)
            return GalleryState(title: product.title, images: product.images)
        } catch {
            // `galleryService.fetchProduct` is `throws(APIError)`: `error` here is
            // already `APIError`, not `any Error`.
            throw GalleryError.from(error)
        }
    }

    public func prefetchImage(url: URL) async {
        await galleryService.prefetchImage(url: url)
    }
}

import AppFoundation
import CoreNetworking
import Domain
import Foundation

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

public enum GalleryError: DomainError, Equatable {
    case offline
    case notFound
    case server
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .notFound: false
        case .offline, .server, .unknown: true
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .offline:
            return ScreenError(title: "Sin conexión", message: "Comprueba tu red e inténtalo de nuevo.")
        case .notFound:
            return ScreenError(title: "No encontrado", message: "Este producto ya no está disponible.")
        case .server:
            return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
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
            throw Self.mapError(error)
        }
    }

    public func prefetchImage(url: URL) async {
        await galleryService.prefetchImage(url: url)
    }

    private static func mapError(_ error: APIError) -> GalleryError {
        switch error.category {
        case .offline: return .offline
        case .notFound: return .notFound
        case .server: return .server
        default: return .unknown
        }
    }
}

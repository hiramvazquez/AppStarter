import AppFoundation
import CoreNetworking
import Domain
import Foundation

// MARK: - The domain model

/// What a successful upload produces — `Sendable`/`Equatable`, never the DTO (M2): see
/// `Services/UploadsService.swift`.
public nonisolated struct UploadedProduct: Sendable, Equatable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

// MARK: - Domain errors (M1)

public enum UploadsError: DomainError, Equatable {
    case captureCancelled
    case captureFailed
    case offline
    case server
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .offline, .server, .unknown: return true
        case .captureCancelled, .captureFailed: return false
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .captureCancelled:
            return ScreenError(title: "Cancelado", message: "No se tomó ninguna foto.")
        case .captureFailed:
            return ScreenError(title: "No se pudo capturar", message: "Inténtalo de nuevo.")
        case .offline:
            return ScreenError(title: "Sin conexión", message: "Comprueba tu red e inténtalo de nuevo.")
        case .server:
            return ScreenError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        case .unknown:
            return ScreenError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        }
    }
}

// MARK: - Logic

/// Every operation `UploadsViewModel` can ask its `Logic` for.
public protocol UploadsLogicProtocol: Logic {
    /// Captures a photo via `any CameraCapturing` — mapped to `UploadsError` on failure
    /// (the ONE place `CameraCaptureError` gets translated, M1).
    func capturePhoto() async throws -> Data

    /// Uploads `photoData` as `title`'s product photo, tracking a `"upload"` analytics
    /// event on success.
    func upload(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadedProduct
}

/// ALL of the Uploads feature's business logic: one call to `UploadsServicing`
/// (`Networking`'s authenticated `APIServiceProtocol`), one call to `any CameraCapturing`
/// (`Domain`, implemented by `CameraKit`), and one `AnalyticsTracking` event on success.
///
/// `nonisolated` (M5): not tied to the main actor.
public nonisolated final class UploadsLogic: UploadsLogicProtocol {
    private let uploadsService: any UploadsServicing
    private let camera: any CameraCapturing
    private let analytics: any AnalyticsTracking

    public init(uploadsService: any UploadsServicing, camera: any CameraCapturing, analytics: any AnalyticsTracking) {
        self.uploadsService = uploadsService
        self.camera = camera
        self.analytics = analytics
    }

    public func capturePhoto() async throws -> Data {
        do {
            return try await camera.capturePhoto()
        } catch CameraCaptureError.cancelled {
            throw UploadsError.captureCancelled
        } catch {
            throw UploadsError.captureFailed
        }
    }

    public func upload(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadedProduct {
        do {
            let result = try await uploadsService.addProduct(title: title, photoData: photoData, progress: progress)
            await analytics.track(AnalyticsEvent(name: "upload", parameters: ["product_id": "\(result.id)"]))
            return result
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: APIError) -> UploadsError {
        switch error.category {
        case .offline: return .offline
        case .server: return .server
        default: return .unknown
        }
    }
}

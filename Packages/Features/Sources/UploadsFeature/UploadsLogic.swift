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
    /// El usuario cerró la cámara sin disparar. NO es lo mismo que `.cancelled`: no viene de
    /// la red y esta pantalla lo presenta a sabiendas como su resultado, así que la spec
    /// `plataforma` lo deja fuera de las otras tres cláusulas a propósito.
    case captureCancelled
    case captureFailed
    case offline
    case server
    /// La SUBIDA se canceló, que es cancelación de red y por tanto lo contrario del caso de
    /// arriba: nunca debe llegar a pantalla. Existe porque la spec `plataforma` lo exige de
    /// toda feature que lance una cancelación venida de la red: se mapea desde
    /// `APIError.Category.cancelled` en vez de caer en `.unknown`, no es reintentable, y
    /// `AppCancellationRecognizer` lo reconoce para que `BaseViewModel` no lo presente.
    case cancelled
    case unknown

    public var isRetryable: Bool {
        switch self {
        case .offline, .server, .unknown: return true
        case .captureCancelled, .captureFailed, .cancelled: return false
        }
    }

    public var screenError: ScreenError {
        switch self {
        case .captureCancelled:
            return ScreenError(title: "Cancelado", message: "No se tomó ninguna foto.")
        case .captureFailed:
            return ScreenError(title: "No se pudo capturar", message: "Inténtalo de nuevo.")
        case .offline:
            return ScreenError(title: ErrorCopy.Offline.title, message: ErrorCopy.Offline.message)
        case .server:
            return ScreenError(title: ErrorCopy.Server.title, message: ErrorCopy.Server.message)
        case .cancelled:
            return ScreenError(title: ErrorCopy.Cancelled.title, message: ErrorCopy.Cancelled.message)
        case .unknown:
            return ScreenError(title: ErrorCopy.Unknown.title, message: ErrorCopy.Unknown.message)
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
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

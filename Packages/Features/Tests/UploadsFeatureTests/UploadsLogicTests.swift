import AppFoundationTestSupport
import CoreNetworking
import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import UploadsFeature

@Suite("UploadsLogic")
struct UploadsLogicTests {
    @Test("capturePhoto() returns what the camera returns")
    func capturePhotoReturnsCameraData() async throws {
        let camera = CameraCapturingMock()
        await camera.setResultToReturn(.success(Data([0xAA, 0xBB])))
        let logic = UploadsLogic(uploadsService: UploadsServiceMock(), camera: camera, analytics: InMemoryAnalytics())

        let data = try await logic.capturePhoto()

        #expect(data == Data([0xAA, 0xBB]))
        #expect(await camera.captureCalls.count == 1)
    }

    @Test("A CameraCaptureError.cancelled maps to UploadsError.captureCancelled")
    func cancelledCaptureMapsToDomainError() async {
        let camera = CameraCapturingMock()
        await camera.setResultToReturn(.failure(CameraCaptureError.cancelled))
        let logic = UploadsLogic(uploadsService: UploadsServiceMock(), camera: camera, analytics: InMemoryAnalytics())

        await #expect(throws: UploadsError.captureCancelled) {
            _ = try await logic.capturePhoto()
        }
    }

    @Test("Any other camera failure maps to UploadsError.captureFailed")
    func otherCaptureFailureMapsToDomainError() async {
        struct SomeCameraError: Error {}
        let camera = CameraCapturingMock()
        await camera.setResultToReturn(.failure(SomeCameraError()))
        let logic = UploadsLogic(uploadsService: UploadsServiceMock(), camera: camera, analytics: InMemoryAnalytics())

        await #expect(throws: UploadsError.captureFailed) {
            _ = try await logic.capturePhoto()
        }
    }

    @Test("upload(_:) returns what the service returns and tracks an analytics event")
    func uploadReturnsServiceResultAndTracksEvent() async throws {
        let service = UploadsServiceMock()
        let product = UploadedProduct(id: 42, title: "Widget")
        await service.setResultToReturn(.success(product))
        let analytics = InMemoryAnalytics()
        let logic = UploadsLogic(uploadsService: service, camera: CameraCapturingMock(), analytics: analytics)

        let result = try await logic.upload(title: "Widget", photoData: Data(), progress: { _ in })

        #expect(result == product)
        let tracked = await analytics.trackedEvents.calls
        #expect(tracked.count == 1)
        #expect(tracked.first?.name == "upload")
        #expect(tracked.first?.parameters["product_id"] == "42")
    }

    @Test("upload(_:) forwards progress fractions from the Service")
    func uploadForwardsProgress() async throws {
        let service = UploadsServiceMock()
        await service.setProgressToReport([0.25, 0.75, 1.0])
        let logic = UploadsLogic(uploadsService: service, camera: CameraCapturingMock(), analytics: InMemoryAnalytics())

        // A locked array, recorded SYNCHRONOUSLY inside the (non-`async`) progress
        // closure — `UploadsServiceMock.addProduct` calls it in a plain sequential
        // `for` loop, so this preserves call order. Wrapping each call in its own
        // `Task { await recorder.record(...) }` (an earlier version of this test) does
        // NOT: separate unstructured `Task`s racing to enter an actor have no ordering
        // guarantee, which made this test genuinely flaky under parallel test execution.
        let recorder = LockedArray<Double>()
        _ = try await logic.upload(
            title: "Widget",
            photoData: Data(),
            progress: { fraction in recorder.append(fraction) }
        )

        #expect(recorder.values == [0.25, 0.75, 1.0])
    }

    @Test("A server service failure maps to UploadsError.server, without tracking an event")
    func serverFailureMapsToDomainErrorWithoutTracking() async {
        let service = UploadsServiceMock()
        await service.setResultToReturn(.failure(.stub(code: .httpStatus, statusCode: 503)))
        let analytics = InMemoryAnalytics()
        let logic = UploadsLogic(uploadsService: service, camera: CameraCapturingMock(), analytics: analytics)

        await #expect(throws: UploadsError.server) {
            _ = try await logic.upload(title: "Widget", photoData: Data(), progress: { _ in })
        }
        #expect(await analytics.trackedEvents.isEmpty)
    }

    @Test("An offline service failure maps to UploadsError.offline")
    func offlineFailureMapsToDomainError() async {
        let service = UploadsServiceMock()
        let error = APIError.stub(code: .transport, underlying: URLError(.notConnectedToInternet))
        await service.setResultToReturn(.failure(error))
        let logic = UploadsLogic(uploadsService: service, camera: CameraCapturingMock(), analytics: InMemoryAnalytics())

        await #expect(throws: UploadsError.offline) {
            _ = try await logic.upload(title: "Widget", photoData: Data(), progress: { _ in })
        }
    }
}

/// A plain lock-guarded array — simpler than `SpyRecorder` for a value recorded from a
/// SYNCHRONOUS, non-`async` closure (`upload`'s `progress:` parameter): no actor hop, so
/// no ordering ambiguity between concurrent callers.
///
/// `nonisolated`: this project's `defaultIsolation(MainActor.self)` would otherwise make
/// `append`/`values` main-actor-isolated, but `progress:` calls this from whatever
/// (non-main) context `UploadsServiceMock.addProduct` runs in — a real `NSLock`, not the
/// main actor, is what makes this safe to call from there synchronously.
nonisolated private final class LockedArray<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(element)
    }

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

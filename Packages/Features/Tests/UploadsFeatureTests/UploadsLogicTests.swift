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

        let recorder = SpyRecorder<Double>()
        _ = try await logic.upload(
            title: "Widget",
            photoData: Data(),
            progress: { fraction in Task { await recorder.record(fraction) } }
        )
        // The progress closure isn't awaited by `upload` itself (fire-and-forget, like the
        // real `URLSessionTaskDelegate` callbacks it stands in for) — poll instead of a
        // single fixed sleep, so this isn't flaky under CI load.
        let deadline = ContinuousClock.now + .seconds(2)
        while await recorder.count < 3, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(await recorder.calls == [0.25, 0.75, 1.0])
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

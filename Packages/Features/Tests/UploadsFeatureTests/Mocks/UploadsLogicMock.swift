import AppFoundationTestSupport
import Foundation

@testable import UploadsFeature

/// Spy that substitutes `UploadsLogicProtocol` in `UploadsViewModelTests` — the ViewModel
/// under test never touches a real `UploadsLogic`/`UploadsService`/`CameraKit`.
final class UploadsLogicMock: UploadsLogicProtocol, @unchecked Sendable {
    let captureCalls = SpyRecorder<Void>()
    let uploadCalls = SpyRecorder<String>()

    var photoDataToReturn = Data([0x01, 0x02])
    var captureErrorToThrow: (any Error)?

    var uploadResultToReturn = UploadedProduct(id: 1, title: "Stub")
    var uploadErrorToThrow: (any Error)?
    /// Progress fractions `upload(_:)` reports through its `progress` callback before
    /// returning/throwing.
    var progressToReport: [Double] = [0.5, 1.0]

    func capturePhoto() async throws -> Data {
        await captureCalls.record()
        if let captureErrorToThrow { throw captureErrorToThrow }
        return photoDataToReturn
    }

    func upload(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadedProduct {
        await uploadCalls.record(title)
        for fraction in progressToReport {
            progress(fraction)
        }
        if let uploadErrorToThrow { throw uploadErrorToThrow }
        return uploadResultToReturn
    }
}

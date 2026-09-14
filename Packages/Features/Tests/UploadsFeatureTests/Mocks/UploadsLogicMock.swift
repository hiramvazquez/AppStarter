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

    private(set) var uploadCallCount = 0

    /// Deja parada la subida para poder observar la ACTIVIDAD mientras sigue en vuelo. Recibe
    /// el número de llamada por simetría con los demás mocks, aunque aquí solo haya una: a
    /// diferencia de `performLoad`, `activity(style:)` no cancela a la anterior, así que en
    /// esta feature no existe la «subida superada».
    var gate: (@Sendable (Int) async -> Void)?

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
        uploadCallCount += 1
        let llamada = uploadCallCount
        await uploadCalls.record(title)
        for fraction in progressToReport {
            progress(fraction)
        }
        await gate?(llamada)
        if let uploadErrorToThrow { throw uploadErrorToThrow }
        return uploadResultToReturn
    }
}

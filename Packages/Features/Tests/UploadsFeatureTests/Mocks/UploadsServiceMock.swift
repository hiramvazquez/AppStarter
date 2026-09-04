import AppFoundationTestSupport
import CoreNetworking
import Domain
import Foundation

@testable import UploadsFeature

/// Stub that substitutes `UploadsServicing` in `UploadsLogicTests` — the Logic under test
/// never touches `APIServiceProtocol`/a real network call.
///
/// `actor` (M5): a `Servicing` conformance is `Sendable`, and an actor is the direct way
/// to hold mutable stub state behind that requirement.
actor UploadsServiceMock: UploadsServicing {
    let addProductCalls = SpyRecorder<String>()
    var resultToReturn: Result<UploadedProduct, APIError> = .success(UploadedProduct(id: 1, title: "Stub"))
    /// Progress fractions to report before returning/throwing — lets a test assert the
    /// ViewModel actually forwards them into `viewModel.progress`.
    var progressToReport: [Double] = [0.5, 1.0]

    /// Actor-isolated state can't be assigned from outside (`mock.resultToReturn = x` does
    /// not compile) — this is the setter a test awaits instead.
    func setResultToReturn(_ result: Result<UploadedProduct, APIError>) {
        resultToReturn = result
    }

    func setProgressToReport(_ progress: [Double]) {
        progressToReport = progress
    }

    func addProduct(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(APIError) -> UploadedProduct {
        await addProductCalls.record(title)
        for fraction in progressToReport {
            progress(fraction)
        }
        switch resultToReturn {
        case .success(let product): return product
        case .failure(let error): throw error
        }
    }
}

/// Stub that substitutes `CameraCapturing` — never a real `UIImagePickerController`/
/// `SimulatedCamera`. The conformance is declared in a SEPARATE `extension` (same gotcha
/// as `Domain/Session.swift`'s `UserDefaultsSessionStore`: `InferIsolatedConformances` +
/// `defaultIsolation(MainActor)` make an inline conformance to an `async` `Sendable`
/// protocol fail this actor's own synchronous `init`).
actor CameraCapturingMock {
    let captureCalls = SpyRecorder<Void>()
    var resultToReturn: Result<Data, any Error> = .success(Data([0x01]))

    func setResultToReturn(_ result: Result<Data, any Error>) {
        resultToReturn = result
    }
}

extension CameraCapturingMock: CameraCapturing {
    func capturePhoto() async throws -> Data {
        await captureCalls.record()
        switch resultToReturn {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
}

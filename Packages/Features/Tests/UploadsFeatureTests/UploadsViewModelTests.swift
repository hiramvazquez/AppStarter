import Foundation
import Testing

@testable import UploadsFeature

/// `UploadsViewModel` tested only against `UploadsLogicMock` — no `UploadsService`/
/// `CameraKit`/network involved.
@Suite("UploadsViewModel")
@MainActor
struct UploadsViewModelTests {
    @Test("handle(.appear) reaches .content")
    func appearReachesContent() {
        let viewModel = UploadsViewModel(logic: UploadsLogicMock())

        viewModel.handle(.appear)

        #expect(viewModel.phase == .content)
    }

    @Test("handle(.capturePhoto) stores the captured photo data")
    func capturePhotoStoresData() async {
        let mock = UploadsLogicMock()
        mock.photoDataToReturn = Data([0x01, 0x02, 0x03])
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value

        #expect(await mock.captureCalls.count == 1)
        #expect(viewModel.capturedPhotoData == Data([0x01, 0x02, 0x03]))
    }

    @Test("A failing capturePhoto() shows a banner and leaves capturedPhotoData nil")
    func captureFailureShowsBanner() async {
        let mock = UploadsLogicMock()
        mock.captureErrorToThrow = UploadsError.captureFailed
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.capturedPhotoData == nil)
        #expect(viewModel.banner != nil)
    }

    @Test("handle(.upload) is a no-op without a captured photo")
    func uploadWithoutPhotoIsNoOp() async {
        let mock = UploadsLogicMock()
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.upload)
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await mock.uploadCalls.isEmpty)
    }

    @Test("handle(.upload) reports progress, stores the result, and shows a success banner")
    func uploadReportsProgressAndSucceeds() async {
        let mock = UploadsLogicMock()
        mock.photoDataToReturn = Data([0x01])
        mock.progressToReport = [0.3, 0.6, 1.0]
        mock.uploadResultToReturn = UploadedProduct(id: 7, title: "Producto de prueba")
        let viewModel = UploadsViewModel(logic: mock)

        viewModel.handle(.capturePhoto)
        await viewModel.inFlightActivity?.value
        viewModel.handle(.upload)
        await waitUntil { viewModel.uploadedProduct != nil }

        #expect(await mock.uploadCalls.calls == ["Producto de prueba"])
        #expect(viewModel.progress == 1.0)
        #expect(viewModel.uploadedProduct == UploadedProduct(id: 7, title: "Producto de prueba"))
        #expect(viewModel.banner?.style == .success)
    }

    /// `.upload`'s `Task` is privately owned (the structured `activity()` variant, not
    /// `performActivity`) — a test polls observable state instead of awaiting a specific
    /// `Task` handle, same rationale as `DiagnosticsViewModelTests`.
    private func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

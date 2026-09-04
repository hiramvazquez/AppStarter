import Foundation
import SnapshotTesting
import SwiftUI
import UploadsFeature
import XCTest

/// PRD-APP-02, Fase 3: `UploadsView` in loading/empty/error/content, under the kit's own
/// styles and the brand's. Like `DiagnosticsViewModel`, `UploadsViewModel` never fails its
/// own `appear()` — loading/empty/error are injected directly through `BaseViewModel`'s
/// public `setLoading`/`setEmpty`/`setError`.
@MainActor
final class UploadsSnapshotTests: XCTestCase {
    /// A real, decodable 1×1 PNG (`CGImageSourceCreateWithData` needs a genuine image —
    /// `UploadsView.platformImage(from:)` returns `nil`, falling back to "Ninguna foto
    /// todavía.", for anything else) — so the "content" snapshot actually shows the photo
    /// preview `Image`, not the empty-photo placeholder text.
    private static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private final class StubLogic: UploadsLogicProtocol, @unchecked Sendable {
        func capturePhoto() async throws -> Data { UploadsSnapshotTests.onePixelPNG }
        func upload(
            title: String,
            photoData: Data,
            progress: @escaping @Sendable (Double) -> Void
        ) async throws -> UploadedProduct {
            progress(1)
            return UploadedProduct(id: 101, title: title)
        }
    }

    private func makeViewModel() -> UploadsViewModel {
        UploadsViewModel(logic: StubLogic())
    }

    private func assertUploads(
        _ viewModel: UploadsViewModel,
        theme: SnapshotTheme,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view = NavigationStack { UploadsView(viewModel: viewModel) }
            .snapshotTheme(theme)
            .frame(width: snapshotDeviceSize.width, height: snapshotDeviceSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .fixed(
                    width: snapshotDeviceSize.width,
                    height: snapshotDeviceSize.height
                )
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    func testLoadingKit() {
        let vm = makeViewModel()
        vm.setLoading(.fullScreen)
        assertUploads(vm, theme: .kit, named: "kit")
    }

    func testLoadingBrand() {
        let vm = makeViewModel()
        vm.setLoading(.fullScreen)
        assertUploads(vm, theme: .brand, named: "brand")
    }

    func testEmptyKit() {
        let vm = makeViewModel()
        vm.setEmpty()
        assertUploads(vm, theme: .kit, named: "kit")
    }

    func testEmptyBrand() {
        let vm = makeViewModel()
        vm.setEmpty()
        assertUploads(vm, theme: .brand, named: "brand")
    }

    func testErrorKit() {
        let vm = makeViewModel()
        vm.setError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        assertUploads(vm, theme: .kit, named: "kit")
    }

    func testErrorBrand() {
        let vm = makeViewModel()
        vm.setError(title: "Error del servidor", message: "Inténtalo de nuevo más tarde.")
        assertUploads(vm, theme: .brand, named: "brand")
    }

    func testContentKit() async {
        let vm = makeViewModel()
        vm.handle(.appear)
        vm.handle(.capturePhoto)
        await waitUntil(vm.capturedPhotoData != nil)
        vm.handle(.upload)
        await waitUntil(vm.uploadedProduct != nil)
        assertUploads(vm, theme: .kit, named: "kit")
    }

    func testContentBrand() async {
        let vm = makeViewModel()
        vm.handle(.appear)
        vm.handle(.capturePhoto)
        await waitUntil(vm.capturedPhotoData != nil)
        vm.handle(.upload)
        await waitUntil(vm.uploadedProduct != nil)
        assertUploads(vm, theme: .brand, named: "brand")
    }
}

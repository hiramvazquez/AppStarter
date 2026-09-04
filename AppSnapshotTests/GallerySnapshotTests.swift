import AppFoundation
import Domain
import Foundation
import GalleryFeatureCore
import GalleryFeatureUI
import SnapshotTesting
import SwiftUI
import XCTest

/// PRD-APP-02, Fase 3: `GalleryView` in loading/empty/error/content, under the kit's own
/// styles and the brand's. Unlike `DiagnosticsViewModel`/`UploadsViewModel`,
/// `GalleryViewModel.load()` (`performLoad(successTransition: .preserveCurrentPhase)`)
/// DOES reach `.empty` (a product with no images) and `.error` (the Logic throws)
/// naturally — this suite drives those two through a real `GalleryLogicProtocol` stub
/// instead of forcing `setEmpty`/`setError` directly, for closer-to-production coverage;
/// `.loading` still uses the direct call (avoids racing the stub's own, near-instant
/// `async` return).
@MainActor
final class GallerySnapshotTests: XCTestCase {
    private enum StubOutcome {
        case content
        case empty
        case failure
    }

    private final class StubLogic: GalleryLogicProtocol, @unchecked Sendable {
        let outcome: StubOutcome

        func load(productID: Int) async throws -> GalleryState {
            switch outcome {
            case .content:
                let base = "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess"
                return GalleryState(
                    title: "Essence Mascara Lash Princess",
                    images: [
                        URL(string: "\(base)/1.webp")!,
                        URL(string: "\(base)/2.webp")!,
                        URL(string: "\(base)/3.webp")!
                    ]
                )
            case .empty:
                return GalleryState(title: "Essence Mascara Lash Princess", images: [])
            case .failure:
                throw GalleryError.server
            }
        }

        func prefetchImage(url: URL) async {}
        init(outcome: StubOutcome) {
            self.outcome = outcome
        }
    }

    private func makeViewModel(outcome: StubOutcome) -> GalleryViewModel {
        GalleryViewModel(
            logic: StubLogic(outcome: outcome),
            productID: 1,
            router: Coordinator<AppRoute>(root: .products)
        )
    }

    private func assertGallery(
        _ viewModel: GalleryViewModel,
        theme: SnapshotTheme,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view = GalleryView(viewModel: viewModel)
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
        let vm = makeViewModel(outcome: .content)
        vm.setLoading(.fullScreen)
        assertGallery(vm, theme: .kit, named: "kit")
    }

    func testLoadingBrand() {
        let vm = makeViewModel(outcome: .content)
        vm.setLoading(.fullScreen)
        assertGallery(vm, theme: .brand, named: "brand")
    }

    func testEmptyKit() async {
        let vm = makeViewModel(outcome: .empty)
        vm.handle(.load)
        await waitUntil(vm.isEmpty)
        assertGallery(vm, theme: .kit, named: "kit")
    }

    func testEmptyBrand() async {
        let vm = makeViewModel(outcome: .empty)
        vm.handle(.load)
        await waitUntil(vm.isEmpty)
        assertGallery(vm, theme: .brand, named: "brand")
    }

    func testErrorKit() async {
        let vm = makeViewModel(outcome: .failure)
        vm.handle(.load)
        await waitUntil(vm.hasError)
        assertGallery(vm, theme: .kit, named: "kit")
    }

    func testErrorBrand() async {
        let vm = makeViewModel(outcome: .failure)
        vm.handle(.load)
        await waitUntil(vm.hasError)
        assertGallery(vm, theme: .brand, named: "brand")
    }

    func testContentKit() async {
        let vm = makeViewModel(outcome: .content)
        vm.handle(.load)
        await waitUntil(vm.isContent)
        assertGallery(vm, theme: .kit, named: "kit")
    }

    func testContentBrand() async {
        let vm = makeViewModel(outcome: .content)
        vm.handle(.load)
        await waitUntil(vm.isContent)
        assertGallery(vm, theme: .brand, named: "brand")
    }
}

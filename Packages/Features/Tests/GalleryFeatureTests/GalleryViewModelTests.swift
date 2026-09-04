import AppFoundation
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import GalleryFeatureCore
@testable import GalleryFeatureUI

/// `GalleryViewModel` tested only against `GalleryLogicMock` — no `GalleryService` real,
/// no network involved.
@Suite("GalleryViewModel")
@MainActor
struct GalleryViewModelTests {
    private static let images = [
        URL(string: "https://cdn.dummyjson.com/a.png")!,
        URL(string: "https://cdn.dummyjson.com/b.png")!,
        URL(string: "https://cdn.dummyjson.com/c.png")!
    ]

    @Test("handle(.load) calls logic.load(productID:) and reaches .content when non-empty")
    func loadReachesContent() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(mock.loadCallCount == 1)
        #expect(viewModel.phase == .content)
        #expect(viewModel.title == "Robot Bear")
        #expect(viewModel.images == Self.images)
    }

    @Test("handle(.load) reaches .empty when the product has no images")
    func loadReachesEmptyWhenNoImages() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: [])
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .empty)
    }

    @Test("A failing logic.load lands on .error")
    func loadFailureSurfacesError() async {
        let mock = GalleryLogicMock()
        mock.errorToThrow = GalleryError.unknown
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.hasError)
    }

    @Test("handle(.select) updates selectedIndex, ignoring an out-of-bounds index")
    func selectUpdatesIndex() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.select(index: 2))
        #expect(viewModel.selectedIndex == 2)

        viewModel.handle(.select(index: 99))
        #expect(viewModel.selectedIndex == 2)
    }

    @Test("handle(.scrolled) throttles a single prefetch of the next image")
    func scrolledThrottlesPrefetchOfNextImage() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.scrolled(toIndex: 0))
        viewModel.handle(.scrolled(toIndex: 1))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.selectedIndex == 1)
        #expect(mock.prefetchedURLs.contains(Self.images[1]))
    }

    @Test("handle(.scrolled) at the last image does not prefetch past the end")
    func scrolledAtLastImageDoesNotPrefetch() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        viewModel.handle(.scrolled(toIndex: Self.images.count - 1))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(mock.prefetchedURLs.isEmpty)
    }

    @Test("handle(.share) sets shareURL to the currently selected image; .dismissShare clears it")
    func shareSetsCurrentImageURL() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.select(index: 1))

        viewModel.handle(.share)
        #expect(viewModel.shareURL == Self.images[1])

        viewModel.handle(.dismissShare)
        #expect(viewModel.shareURL == nil)
    }

    @Test("handle(.close) pops the router")
    func closePopsRouter() {
        let mock = GalleryLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.push(.gallery(productID: 3))
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: router)

        viewModel.handle(.close)

        #expect(router.mainStack.path.isEmpty)
    }

    @Test("Changing images notifies Observation — GalleryViewModel's own @Observable (docs/INFORME-MULTI.md §11)")
    func changingImagesNotifiesObservation() async {
        let mock = GalleryLogicMock()
        mock.stateToReturn = GalleryState(title: "Robot Bear", images: Self.images)
        let viewModel = GalleryViewModel(logic: mock, productID: 3, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.images
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}

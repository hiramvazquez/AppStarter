import AppFoundation
import Domain
import Foundation
import GalleryFeatureCore
import Observation

/// Orchestrates the Gallery screen: load the product's images, track which one is
/// currently visible, throttle prefetching the next one as the user swipes, and share
/// the current image. Never imports CoreNetworking, never references `GalleryService`
/// directly — only `logic`.
///
/// `@Observable` here too (PRD-APP-02 tramo B item 0, docs/INFORME-MULTI.md §11): the
/// macro only instruments stored properties declared IN this class, so `title`/`images`/
/// `selectedIndex`/`shareURL` need their own.
@MainActor
@Observable
public final class GalleryViewModel: LogicViewModel<any GalleryLogicProtocol>, ActionHandling {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    public let productID: Int
    public private(set) var title: String = ""
    public private(set) var images: [URL] = []
    public private(set) var selectedIndex: Int = 0
    public private(set) var shareURL: URL?

    private let router: any Router<AppRoute>

    /// `Throttler`, not `Debouncer` (PRD-APP-02: Search gets the debounce, Gallery gets
    /// the throttle — both documented, `Utilities.md`): a scroll can settle on several
    /// images in quick succession, and each settle should still warm the NEXT image
    /// promptly rather than waiting for scrolling to stop entirely — at most one prefetch
    /// per window, not "prefetch only once scrolling stops."
    private let prefetchThrottler: Throttler

    /// The prefetch `Task` `scrolled(toIndex:)` last spawned — `internal`, not `public`
    /// (mirrors `BaseViewModel.inFlightLoad`/`inFlightActivity`'s own visibility): tests
    /// `await` it instead of a real `Task.sleep`, the same reason those two properties
    /// exist on the kit's own `BaseViewModel`.
    private(set) var inFlightPrefetch: Task<Void, Never>?

    public enum Action: Sendable {
        case load
        case select(index: Int)
        case scrolled(toIndex: Int)
        case close
        case share
        case dismissShare
    }

    /// - Parameter clock: Forwarded to `Throttler`. Defaults to `ContinuousClock`;
    ///   `GalleryViewModelTests` injects `AppFoundationTestSupport.ManualClock` so the
    ///   throttle window advances deterministically instead of a real `Task.sleep`
    ///   (PRD-APP-02 tramo B item 6: "Throttler/Debouncer con ManualClock").
    public init(
        logic: any GalleryLogicProtocol,
        productID: Int,
        router: any Router<AppRoute>,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.productID = productID
        self.router = router
        self.prefetchThrottler = Throttler(interval: .milliseconds(400), clock: clock)
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .select(let index): select(index)
        case .scrolled(let index): scrolled(toIndex: index)
        case .close: router.pop()
        case .share: share()
        case .dismissShare: shareURL = nil
        }
    }

    private func load() {
        // `.preserveCurrentPhase`: the work closure picks between `.content`/`.empty`
        // itself — the default `successTransition` would force `.content` afterward and
        // silently discard `setEmpty()` (a product with no images, e.g. a fixture).
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            let state = try await vm.logic.load(productID: vm.productID)
            vm.title = state.title
            vm.images = state.images
            if state.images.isEmpty { vm.setEmpty() } else { vm.setContent() }
        }
    }

    private func select(_ index: Int) {
        guard images.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Called as the user swipes between images — the View reports the index it landed
    /// on. Throttled: prefetching the NEXT image (not the one just shown, already
    /// on-screen) is expensive enough that firing it on every intermediate index during a
    /// fast swipe would waste bandwidth for images the user never lingers on.
    private func scrolled(toIndex index: Int) {
        select(index)
        let nextIndex = index + 1
        guard images.indices.contains(nextIndex) else { return }
        let nextURL = images[nextIndex]
        let logic = logic
        inFlightPrefetch = Task { [prefetchThrottler] in
            await prefetchThrottler.throttle {
                await logic.prefetchImage(url: nextURL)
            }
        }
    }

    private func share() {
        guard images.indices.contains(selectedIndex) else { return }
        shareURL = images[selectedIndex]
    }
}

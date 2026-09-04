import AppFoundation
import AppFoundationTestSupport
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import SearchFeature

/// Yields until `condition` holds — no real sleeps. Same idiom as
/// `AppFoundationTests.DebouncerTests`' own `settle(until:)`, `async` here (not just
/// `@MainActor`) because the condition itself reads `SpyRecorder` (an actor) — polling a
/// SYNCHRONOUS condition like `inFlightLoad != nil` would race: nothing sets
/// `inFlightLoad` until the debounced `Task` itself gets scheduled after
/// `ManualClock.advance(by:)`, so there is no safe synchronous instant to observe it
/// transition from `nil`. Polling the actual side effect (a recorded call) has no such
/// window.
private func settle(until condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {
    @Test("handle(.submit) calls logic.search and reaches .content")
    func submitReachesContent() async {
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.updateQuery("phone"))
        viewModel.handle(.submit)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.phase == .content)
        #expect(viewModel.results == [product])
    }

    @Test("handle(.updateQuery) debounces — the Logic isn't called until the window elapses")
    func updateQueryDebouncesBeforeSearching() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        mock.resultsToReturn = []
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("phone"))
        #expect(await mock.searchCalls.calls.isEmpty, "the Logic must not be called before the debounce window elapses")

        await clock.waitUntilSleeping()
        clock.advance(by: .milliseconds(300))
        await settle { !(await mock.searchCalls.calls.isEmpty) }

        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("Rapid handle(.updateQuery) calls coalesce into a single search for the LAST query")
    func rapidUpdateQueryCoalescesIntoOneSearch() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        mock.resultsToReturn = []
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("p"))
        viewModel.handle(.updateQuery("ph"))
        viewModel.handle(.updateQuery("phone"))

        await clock.waitUntilSleeping()
        clock.advance(by: .milliseconds(300))
        await settle { !(await mock.searchCalls.calls.isEmpty) }

        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("handle(.submit) bypasses the debounce and searches immediately")
    func submitBypassesDebounce() async {
        let clock = ManualClock()
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), clock: clock)

        viewModel.handle(.updateQuery("phone"))
        viewModel.handle(.submit)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.results == [product])
        // The debounce this cancelled never fires: advancing the clock past its window
        // must not trigger a SECOND search.
        clock.advance(by: .milliseconds(300))
        await Task.yield()
        #expect(await mock.searchCalls.calls == ["phone"])
    }

    @Test("An empty query clears results without calling the logic")
    func emptyQueryClearsResults() async {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.updateQuery(""))

        #expect(await mock.searchCalls.calls.isEmpty)
        #expect(viewModel.results.isEmpty)
    }

    @Test("An initialQuery seeds query and handle(.appear) submits it once")
    func initialQueryAutoSubmits() async {
        let mock = SearchLogicMock()
        let product = Product(id: 1, title: "Phone", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.resultsToReturn = [product]
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products), initialQuery: "phone")

        #expect(viewModel.query == "phone")
        viewModel.handle(.appear)
        await viewModel.inFlightLoad?.value

        #expect(await mock.searchCalls.calls == ["phone"])
        #expect(viewModel.results == [product])
    }

    @Test("A nil initialQuery (plain \"open search\") never auto-submits on appear")
    func nilInitialQueryDoesNotAutoSubmit() {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.appear)

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.phase == .idle)
    }

    @Test("handle(.selectProduct) dismisses the sheet and pushes the detail")
    func selectProductDismissesAndPushes() {
        let mock = SearchLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.present(.search(query: nil), as: .sheet)
        let viewModel = SearchViewModel(logic: mock, router: router)

        viewModel.handle(.selectProduct(id: 5))

        #expect(router.modal == nil)
        #expect(router.mainStack.path == [.productDetail(id: 5)])
    }

    @Test("Changing query notifies Observation — SearchViewModel declares its own @Observable (§11)")
    func changingQueryNotifiesObservation() {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.query
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.updateQuery("phone"))

        #expect(flag.fired)
    }
}

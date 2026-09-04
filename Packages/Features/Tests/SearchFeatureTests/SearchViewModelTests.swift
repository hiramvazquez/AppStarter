import AppFoundation
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import SearchFeature

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

    @Test("An empty query clears results without calling the logic")
    func emptyQueryClearsResults() async {
        let mock = SearchLogicMock()
        let viewModel = SearchViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.updateQuery(""))

        #expect(await mock.searchCalls.calls.isEmpty)
        #expect(viewModel.results.isEmpty)
    }

    @Test("handle(.selectProduct) dismisses the sheet and pushes the detail")
    func selectProductDismissesAndPushes() {
        let mock = SearchLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.present(.search, as: .sheet)
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

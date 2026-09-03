import AppFoundation
import Foundation
import Testing

@testable import AppStarterKit

@Suite("FavoritesViewModel")
@MainActor
struct FavoritesViewModelTests {
    @Test("handle(.load) reaches .empty when there is nothing favorited")
    func loadReachesEmptyWhenNothing() async {
        let mock = FavoritesLogicMock()
        mock.itemsToReturn = []
        let viewModel = FavoritesViewModel(logic: mock, router: Coordinator(root: .favorites))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .empty)
    }

    @Test("handle(.remove) removes the item from the visible list")
    func removeUpdatesList() async {
        let mock = FavoritesLogicMock()
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.itemsToReturn = [product]
        let viewModel = FavoritesViewModel(logic: mock, router: Coordinator(root: .favorites))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.remove(id: 1))
        await viewModel.inFlightActivity?.value

        #expect(await mock.removeCalls.calls == [1])
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.phase == .empty)
    }

    @Test("handle(.selectProduct) pushes .productDetail(id:)")
    func selectProductPushesDetail() {
        let mock = FavoritesLogicMock()
        let router = Coordinator<AppRoute>(root: .favorites)
        let viewModel = FavoritesViewModel(logic: mock, router: router)

        viewModel.handle(.selectProduct(id: 3))

        #expect(router.mainStack.path == [.productDetail(id: 3)])
    }
}

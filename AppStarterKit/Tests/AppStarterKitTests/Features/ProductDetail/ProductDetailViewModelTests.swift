import AppFoundation
import Foundation
import Testing

@testable import AppStarterKit

@Suite("ProductDetailViewModel")
@MainActor
struct ProductDetailViewModelTests {
    @Test("handle(.load) calls logic.load(id:) and reaches .content")
    func loadReachesContent() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: true)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadCalls.calls == [7])
        #expect(viewModel.phase == .content)
        #expect(viewModel.product == product)
        #expect(viewModel.isFavorite)
    }

    @Test("handle(.toggleFavorite) updates isFavorite from the logic's result")
    func toggleFavoriteUpdatesState() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: false)
        mock.toggleResult = true
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.toggleFavorite)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.isFavorite)
    }

    @Test("handle(.back) pops the router")
    func backPopsRouter() {
        let mock = ProductDetailLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        router.push(.productDetail(id: 1))
        let viewModel = ProductDetailViewModel(logic: mock, productID: 1, router: router)

        viewModel.handle(.back)

        #expect(router.mainStack.path.isEmpty)
    }
}

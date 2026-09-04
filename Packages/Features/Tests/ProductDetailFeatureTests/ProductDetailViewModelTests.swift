import AppFoundation
import Domain
import Foundation
import Observation
import PlatformTestSupport
import Testing

@testable import ProductDetailFeature

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

    @Test("handle(.openGallery) pushes .gallery(productID:)")
    func openGalleryPushesGalleryRoute() {
        let mock = ProductDetailLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: router)

        viewModel.handle(.openGallery)

        #expect(router.mainStack.path == [.gallery(productID: 7)])
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

    @Test(
        "Changing product notifies Observation — ProductDetailViewModel's own @Observable (docs/INFORME-MULTI.md §11)"
    )
    func changingProductNotifiesObservation() async {
        let mock = ProductDetailLogicMock()
        let product = Product(id: 7, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil)
        mock.stateToReturn = ProductDetailState(product: product, isFavorite: true)
        let viewModel = ProductDetailViewModel(logic: mock, productID: 7, router: Coordinator(root: .products))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.product
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}

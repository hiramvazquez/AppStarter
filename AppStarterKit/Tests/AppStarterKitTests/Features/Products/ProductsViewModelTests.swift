import AppFoundation
import Foundation
import Testing

@testable import AppStarterKit

@Suite("ProductsViewModel")
@MainActor
struct ProductsViewModelTests {
    @Test("handle(.load) calls logic.loadPage(skip: 0) and reaches .content")
    func loadReachesContent() async {
        let mock = ProductsLogicMock()
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [product], total: 1, skip: 0, limit: 20)
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadPageCalls.calls == [0])
        #expect(viewModel.phase == .content)
        #expect(viewModel.items == [product])
    }

    @Test(".load only runs once — a second .load with items already present is a no-op")
    func loadOnlyRunsOnce() async {
        let mock = ProductsLogicMock()
        mock.pageToReturn = ProductsPage(
            items: [Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)],
            total: 1,
            skip: 0,
            limit: 20
        )
        let viewModel = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(await mock.loadPageCalls.count == 1)
    }

    @Test(".selectProduct pushes .productDetail(id:)")
    func selectProductPushesDetail() {
        let mock = ProductsLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.selectProduct(id: 42))

        #expect(router.mainStack.path == [.productDetail(id: 42)])
    }

    @Test(".openSearch presents .search as a sheet")
    func openSearchPresentsSheet() {
        let mock = ProductsLogicMock()
        let router = Coordinator<AppRoute>(root: .products)
        let viewModel = ProductsViewModel(logic: mock, router: router)

        viewModel.handle(.openSearch)

        #expect(router.sheetStack?.root == .search)
    }

    @Test(".loadMore appends the next page when canLoadMore")
    func loadMoreAppendsNextPage() async {
        let mock = ProductsLogicMock()
        let first = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        let second = Product(id: 2, title: "B", description: "", price: 2, rating: 2, thumbnailURL: nil)
        mock.pageToReturn = ProductsPage(items: [first], total: 2, skip: 0, limit: 1)
        let viewModel = ProductsViewModel(logic: mock, router: Coordinator(root: .products))

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value
        #expect(viewModel.canLoadMore)

        mock.pageToReturn = ProductsPage(items: [second], total: 2, skip: 1, limit: 1)
        viewModel.handle(.loadMore)
        await viewModel.inFlightActivity?.value

        #expect(viewModel.items == [first, second])
        #expect(viewModel.canLoadMore == false)
    }
}

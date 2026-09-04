import AppFoundation
import Domain
import Foundation
import Observation

/// Orchestrates the product list: pagination, pull-to-refresh, and navigation to
/// `.productDetail`/`.favorites`/`.profile`/`.search`. Never imports CoreNetworking, never
/// references `ProductsService` directly — only `logic`.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to. `items`/`canLoadMore` always mutate alongside
/// `phase`/`activity` today (every write happens inside `performLoad`/`performActivity`),
/// so this stayed a latent bug rather than a visible one — but PRD-APP-02 tramo B item 0
/// makes it explicit on every ViewModel regardless, not just the two where it was caught.
@MainActor
@Observable
public final class ProductsViewModel: LogicViewModel<any ProductsLogicProtocol>, ActionHandling {
    public private(set) var items: [Product] = []
    public private(set) var canLoadMore = false

    private let router: any Router<AppRoute>

    /// Every action `ProductsView` recognizes.
    public enum Action: Sendable {
        case load
        case refresh
        case loadMore
        case selectProduct(id: Int)
        case openSearch
        case openFavorites
        case openProfile
    }

    public init(logic: any ProductsLogicProtocol, router: any Router<AppRoute>) {
        self.router = router
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .refresh: refresh()
        case .loadMore: loadMore()
        case .selectProduct(let id): router.push(.productDetail(id: id))
        case .openSearch: router.present(.search, as: .sheet)
        case .openFavorites: router.push(.favorites)
        case .openProfile: router.push(.profile)
        }
    }

    /// Only runs once — `ProductsView.onAppear` fires again after popping back from
    /// `ProductDetail`, and this screen has no reason to reload just because the user
    /// looked at one product. Pull-to-refresh (`.refresh`) is the explicit way back.
    private func load() {
        guard items.isEmpty else { return }
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            let page = try await vm.logic.loadPage(skip: 0)
            vm.items = page.items
            vm.canLoadMore = page.hasMore
            if page.items.isEmpty { vm.setEmpty() } else { vm.setContent() }
        }
    }

    private func refresh() {
        performActivity { vm in
            let page = try await vm.logic.loadPage(skip: 0)
            vm.items = page.items
            vm.canLoadMore = page.hasMore
            if page.items.isEmpty {
                vm.setEmpty()
            } else if vm.isEmpty {
                vm.setContent()
            }
        }
    }

    private func loadMore() {
        guard canLoadMore, !isPerformingActivity else { return }
        performActivity { vm in
            let page = try await vm.logic.loadPage(skip: vm.items.count)
            vm.items += page.items
            vm.canLoadMore = page.hasMore
        }
    }
}

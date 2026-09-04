import AppFoundation
import Domain
import Foundation
import Observation

/// Orchestrates the product detail screen: load, toggle favorite, and pop back. Never
/// imports CoreNetworking/SwiftData, never references `ProductsService`/`FavoritesStore`
/// directly — only `logic`.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to, so `product`/`isFavorite` need their own.
/// PRD-APP-02 tramo B item 0: every ViewModel declares it, on principle.
@MainActor
@Observable
public final class ProductDetailViewModel: LogicViewModel<any ProductDetailLogicProtocol>, ActionHandling {
    public let productID: Int
    public private(set) var product: Product?
    public private(set) var isFavorite = false

    let router: any Router<AppRoute>

    public enum Action: Sendable {
        case load
        case toggleFavorite
        case back
        case openGallery
    }

    public init(logic: any ProductDetailLogicProtocol, productID: Int, router: any Router<AppRoute>) {
        self.productID = productID
        self.router = router
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .toggleFavorite: toggleFavorite()
        case .back: router.pop()
        case .openGallery: router.push(.gallery(productID: productID))
        }
    }

    private func load() {
        performLoad { vm in
            let state = try await vm.logic.load(id: vm.productID)
            vm.product = state.product
            vm.isFavorite = state.isFavorite
        }
    }

    private func toggleFavorite() {
        guard let product else { return }
        performActivity(errorHandling: .banner) { vm in
            vm.isFavorite = try await vm.logic.toggleFavorite(product)
        }
    }
}

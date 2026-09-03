import AppFoundation
import Foundation

/// Orchestrates the favorites list: load, remove, and push to `ProductDetail`. Never
/// imports SwiftData, never references `FavoritesStore` directly — only `logic`.
@MainActor
public final class FavoritesViewModel: LogicViewModel<any FavoritesLogicProtocol>, ActionHandling {
    public private(set) var items: [Product] = []

    private let router: any Router<AppRoute>

    public enum Action: Sendable {
        case load
        case remove(id: Int)
        case selectProduct(id: Int)
    }

    public init(logic: any FavoritesLogicProtocol, router: any Router<AppRoute>) {
        self.router = router
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .remove(let id): remove(id: id)
        case .selectProduct(let id): router.push(.productDetail(id: id))
        }
    }

    private func load() {
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            let items = try await vm.logic.loadFavorites()
            vm.items = items
            if items.isEmpty { vm.setEmpty() } else { vm.setContent() }
        }
    }

    private func remove(id: Int) {
        performActivity { vm in
            try await vm.logic.remove(id: id)
            vm.items.removeAll { $0.id == id }
            if vm.items.isEmpty { vm.setEmpty() }
        }
    }
}

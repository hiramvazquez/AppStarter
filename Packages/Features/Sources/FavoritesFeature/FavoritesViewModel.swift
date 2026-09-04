import AppFoundation
import Domain
import Foundation
import Observation

/// Orchestrates the favorites list: load, remove, and push to `ProductDetail`. Never
/// imports SwiftData, never references `FavoritesStore` directly — only `logic`.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to, so `items` needs its own. PRD-APP-02 tramo B
/// item 0: every ViewModel declares it, on principle.
@MainActor
@Observable
public final class FavoritesViewModel: LogicViewModel<any FavoritesLogicProtocol>, ActionHandling {
    public private(set) var items: [Product] = []

    private let router: any Router<AppRoute>

    public enum Action: Sendable {
        case load
        case remove(id: Int)
        case selectProduct(id: Int)
        /// Shows the destructive confirmation alert (A15) — never clears directly: a
        /// swipe-to-delete has an undo affordance, but "vaciar" a whole list does not.
        case clearAllRequested
        case clearAll
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
        case .clearAllRequested: requestClearAll()
        case .clearAll: clearAll()
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

    private func requestClearAll() {
        showAlert(
            .destructive(
                title: "Vaciar favoritos",
                message: "Se eliminarán todos los productos favoritos. Esta acción no se puede deshacer.",
                confirm: "Vaciar",
                cancel: "Cancelar",
                onConfirm: { [weak self] in self?.handle(.clearAll) }
            )
        )
    }

    private func clearAll() {
        performActivity { vm in
            try await vm.logic.clearAll()
            vm.items.removeAll()
            vm.setEmpty()
        }
    }
}

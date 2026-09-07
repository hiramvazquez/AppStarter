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
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

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
        case .openSearch: router.present(.search(query: nil), as: .sheet)
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
        // Una cancelación reconocida sale de `performLoad`/`performActivity` por un
        // `return` seco: no toca `phase` ni `activity`, así que la fase transitoria que se
        // puso ANTES de arrancar se queda puesta. Sin esto, cancelar dejaba la pantalla en
        // `.loading(.fullScreen)` para siempre —contenido oculto, sin error, sin
        // reintentar, sin salida—, que es PEOR que el bug que este cambio arregla.
        // Se devuelve el estado a algo honesto y se relanza para que el reconocedor haga
        // su trabajo: no mostrar nada.
            do {
                let page = try await vm.logic.loadPage(skip: 0)
                vm.items = page.items
                vm.canLoadMore = page.hasMore
                if page.items.isEmpty { vm.setEmpty() } else { vm.setContent() }
            } catch ProductsError.cancelled {
                // Solo si esta Task sigue viva: `performLoad` cancela la anterior al
                // arrancar, así que la superada se desenrolla por aquí con `.cancelled` y
                // sin esta condición resetearía la fase de la que la superó — quitándole
                // el spinner a una carga que sigue en vuelo. El `guard !Task.isCancelled`
                // de AppFoundation no cubre esto: está DESPUÉS del closure.
                if !Task.isCancelled { vm.setIdle() }
                throw ProductsError.cancelled
            }
        }
    }

    private func refresh() {
        performActivity { vm in
            do {
                let page = try await vm.logic.loadPage(skip: 0)
                vm.items = page.items
                vm.canLoadMore = page.hasMore
                if page.items.isEmpty {
                    vm.setEmpty()
                } else if vm.isEmpty {
                    vm.setContent()
                }
            } catch ProductsError.cancelled {
                // Mismo motivo que en `load()`: sin esto el scrim del `.overlay` se queda
                // encima para siempre, y `loadMore` muere con él por su
                // `guard !isPerformingActivity`.
                // Solo si esta Task sigue viva: `performLoad` cancela la anterior al
                // arrancar, así que la superada se desenrolla por aquí con `.cancelled` y
                // sin esta condición resetearía la fase de la que la superó — quitándole
                // el spinner a una carga que sigue en vuelo. El `guard !Task.isCancelled`
                // de AppFoundation no cubre esto: está DESPUÉS del closure.
                if !Task.isCancelled { vm.stopActivity() }
                throw ProductsError.cancelled
            }
        }
    }

    private func loadMore() {
        guard canLoadMore, !isPerformingActivity else { return }
        performActivity { vm in
            do {
                let page = try await vm.logic.loadPage(skip: vm.items.count)
                vm.items += page.items
                vm.canLoadMore = page.hasMore
            } catch ProductsError.cancelled {
                // Sin esto el overlay se queda encima
                // y la paginación muere DEL TODO, porque el `guard !isPerformingActivity`
                // de arriba ya no vuelve a pasar nunca.
                // Solo si esta Task sigue viva: `performLoad` cancela la anterior al
                // arrancar, así que la superada se desenrolla por aquí con `.cancelled` y
                // sin esta condición resetearía la fase de la que la superó — quitándole
                // el spinner a una carga que sigue en vuelo. El `guard !Task.isCancelled`
                // de AppFoundation no cubre esto: está DESPUÉS del closure.
                if !Task.isCancelled { vm.stopActivity() }
                throw ProductsError.cancelled
            }
        }
    }
}

import AppFoundation
import Domain
import Foundation
import Observation

/// Orchestrates the search sheet: query text, submit, select a result, close. Never
/// imports CoreNetworking, never references `SearchService`/`ProductsService` directly —
/// only `logic`.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to. `query` mutates OUTSIDE any `performLoad`/
/// `performActivity` (`.updateQuery`, on every keystroke) — this is the one ViewModel in
/// this repo where the bug §11 describes would have been directly visible (the search
/// field's own text not updating as you type), not merely latent. PRD-APP-02 tramo B item
/// 0: every ViewModel declares it, on principle.
@MainActor
@Observable
public final class SearchViewModel: LogicViewModel<any SearchLogicProtocol>, ActionHandling {
    public private(set) var query = ""
    public private(set) var results: [Product] = []

    private let router: any Router<AppRoute>

    public enum Action: Sendable {
        case appear
        case updateQuery(String)
        case submit
        case selectProduct(id: Int)
        case close
    }

    /// - Parameter initialQuery: Pre-fills `query` when the screen opens already carrying
    ///   one — a deep link (`appstarter://search?q=…`, PRD-APP-02 tramo B item 3) via
    ///   `AppRoute.search(query:)`. `nil` (the plain "open search" case,
    ///   `ProductsViewModel.openSearch`) leaves `query` empty, exactly as before.
    public init(logic: any SearchLogicProtocol, router: any Router<AppRoute>, initialQuery: String? = nil) {
        self.router = router
        self.query = initialQuery ?? ""
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .appear:
            // Only a deep link's pre-filled query auto-submits — the plain "open search"
            // sheet (`query` empty) never calls the Logic on appear.
            if !query.isEmpty, results.isEmpty { submit() }
        case .updateQuery(let query):
            self.query = query
            if query.isEmpty {
                results = []
                setIdle()
            }
        case .submit: submit()
        case .selectProduct(let id):
            router.dismiss()
            router.push(.productDetail(id: id))
        case .close: router.dismiss()
        }
    }

    private func submit() {
        guard !query.isEmpty else { return }
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            let results = try await vm.logic.search(query: vm.query)
            vm.results = results
            if results.isEmpty { vm.setEmpty() } else { vm.setContent() }
        }
    }
}

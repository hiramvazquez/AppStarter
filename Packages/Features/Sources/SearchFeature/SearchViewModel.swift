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

    /// Debounces auto-search as the user types (PRD-APP-02 tramo B item 4 —
    /// `SearchBarConfiguration` in the custom `.blur` bar drives `.updateQuery` on every
    /// keystroke): only the LAST keystroke within the window actually calls `logic.search`.
    /// `Gallery` gets `Throttler` instead for its prefetch — both documented in
    /// `Utilities.md`, deliberately different tools for different jobs (coalesce rapid
    /// typing vs. cap a repeating action's rate).
    private let debouncer: Debouncer

    public enum Action: Sendable {
        case appear
        case updateQuery(String)
        case submit
        case selectProduct(id: Int)
        case close
    }

    /// - Parameters:
    ///   - initialQuery: Pre-fills `query` when the screen opens already carrying one — a
    ///     deep link (`appstarter://search?q=…`, PRD-APP-02 tramo B item 3) via
    ///     `AppRoute.search(query:)`. `nil` (the plain "open search" case,
    ///     `ProductsViewModel.openSearch`) leaves `query` empty, exactly as before.
    ///   - clock: Forwarded to the `Debouncer`. Defaults to `ContinuousClock`;
    ///     `SearchViewModelTests` injects `AppFoundationTestSupport.ManualClock` so the
    ///     debounce window advances deterministically (PRD-APP-02 tramo B item 6).
    public init(
        logic: any SearchLogicProtocol,
        router: any Router<AppRoute>,
        initialQuery: String? = nil,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.router = router
        self.query = initialQuery ?? ""
        self.debouncer = Debouncer(delay: .milliseconds(300), clock: clock)
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .appear:
            // Only a deep link's pre-filled query auto-searches — the plain "open search"
            // sheet (`query` empty) never calls the Logic on appear.
            if !query.isEmpty, results.isEmpty { search() }
        case .updateQuery(let query):
            self.query = query
            if query.isEmpty {
                debouncer.cancel()
                results = []
                setIdle()
            } else {
                debouncer.debounce { [weak self] in
                    self?.search()
                }
            }
        case .submit:
            // Explicit submit (Return key, `SearchBarConfiguration.onSubmit`) bypasses the
            // debounce entirely — the user asked for it NOW, not 300ms from now.
            debouncer.cancel()
            search()
        case .selectProduct(let id):
            router.dismiss()
            router.push(.productDetail(id: id))
        case .close: router.dismiss()
        }
    }

    private func search() {
        guard !query.isEmpty else { return }
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            let results = try await vm.logic.search(query: vm.query)
            vm.results = results
            if results.isEmpty { vm.setEmpty() } else { vm.setContent() }
        }
    }
}

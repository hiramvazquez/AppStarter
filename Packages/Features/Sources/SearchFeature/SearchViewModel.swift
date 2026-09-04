import AppFoundation
import Domain
import Foundation

/// Orchestrates the search sheet: query text, submit, select a result, close. Never
/// imports CoreNetworking, never references `SearchService`/`ProductsService` directly —
/// only `logic`.
@MainActor
public final class SearchViewModel: LogicViewModel<any SearchLogicProtocol>, ActionHandling {
    public private(set) var query = ""
    public private(set) var results: [Product] = []

    private let router: any Router<AppRoute>

    public enum Action: Sendable {
        case updateQuery(String)
        case submit
        case selectProduct(id: Int)
        case close
    }

    public init(logic: any SearchLogicProtocol, router: any Router<AppRoute>) {
        self.router = router
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
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

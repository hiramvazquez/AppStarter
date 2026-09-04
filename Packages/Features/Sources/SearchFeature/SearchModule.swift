import AppFoundation
import Foundation
import Networking

/// A `SearchViewModel` needs a runtime `initialQuery` `Container.resolve()` can't supply
/// on its own — `RootView` resolves this factory once and calls it with the query from
/// `AppRoute.search(query:)` each time that route renders (`nil` for the plain "open
/// search" case; a value for a deep link, PRD-APP-02 tramo B item 3). Same pattern as
/// `ProductDetailFeature.ProductDetailViewModelFactory`.
public typealias SearchViewModelFactory = @MainActor (_ initialQuery: String?) -> SearchViewModel

/// Registers the Search feature. `ProductsServicing` (`Networking`) is resolved, never
/// constructed — owned by `ProductsModule`.
public struct SearchModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(SearchLogicProtocol.self) { c in
            SearchLogic(productsService: c.resolve())
        }

        container.register(SearchViewModelFactory.self) { c in
            { initialQuery in
                SearchViewModel(logic: c.resolve(), router: c.resolve(), initialQuery: initialQuery)
            }
        }
    }
}

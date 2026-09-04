import AppFoundation
import Foundation
import Networking

/// Registers the Search feature. `ProductsServicing` (`Networking`) is resolved, never
/// constructed — owned by `ProductsModule`.
public struct SearchModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(SearchLogicProtocol.self) { c in
            SearchLogic(productsService: c.resolve())
        }

        container.register(SearchViewModel.self, lifecycle: .transient) { c in
            SearchViewModel(logic: c.resolve(), router: c.resolve())
        }
    }
}

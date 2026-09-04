import AppFoundation
import Foundation
import Networking

/// Registers the Products feature. `ProductsServicing` is shared with `ProductDetail` and
/// `Search` (both resolve it, never construct their own `ProductsService`) — one
/// registration, three consumers, all through the protocol declared in `Networking`.
public struct ProductsModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(ProductsServicing.self) { c in
            ProductsService(api: c.resolve())
        }

        container.register(ProductsLogicProtocol.self) { c in
            ProductsLogic(productsService: c.resolve())
        }

        container.register(ProductsViewModel.self, lifecycle: .transient) { c in
            ProductsViewModel(logic: c.resolve(), router: c.resolve())
        }
    }
}

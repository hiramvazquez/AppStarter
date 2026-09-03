import AppFoundation
import Foundation

/// A `ProductDetailViewModel` needs a runtime `productID` that `Container.resolve()`
/// can't supply on its own — `RootView` resolves this factory once and calls it with the
/// id from `AppRoute.productDetail(id:)` each time that route renders.
public typealias ProductDetailViewModelFactory = @MainActor (_ productID: Int) -> ProductDetailViewModel

/// Registers the ProductDetail feature. `ProductsServicing` (network) and
/// `FavoritesStoring` (local) are both resolved, never constructed here — they're owned
/// by `ProductsModule`/`FavoritesModule` respectively.
public struct ProductDetailModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(ProductDetailLogicProtocol.self, lifecycle: .transient) { c in
            ProductDetailLogic(productsService: c.resolve(), favoritesStore: c.resolve())
        }

        container.register(ProductDetailViewModelFactory.self) { c in
            { productID in
                ProductDetailViewModel(logic: c.resolve(ProductDetailLogicProtocol.self), productID: productID, router: c.resolve())
            }
        }
    }
}

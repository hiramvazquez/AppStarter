import AppFoundation
import Foundation
import GalleryFeatureCore

/// A `GalleryViewModel` needs a runtime `productID` `Container.resolve()` can't supply on
/// its own — `RootView` resolves this factory once and calls it with the id from
/// `AppRoute.gallery(productID:)` each time that route renders. Same pattern as
/// `ProductDetailFeature.ProductDetailViewModelFactory`.
public typealias GalleryViewModelFactory = @MainActor (_ productID: Int) -> GalleryViewModel

/// Registers the Gallery feature. `APIServiceProtocol` (`CoreNetworking`) is resolved,
/// never constructed here — it's the app's own authenticated pipeline, owned by
/// `NetworkingModule` (`Packages/Platform`): Gallery reuses it exactly like every other
/// feature's Service, rather than building a second, unauthenticated one of its own.
public struct GalleryModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(GalleryServicing.self) { c in
            GalleryService(api: c.resolve())
        }

        container.register(GalleryLogicProtocol.self, lifecycle: .transient) { c in
            GalleryLogic(galleryService: c.resolve())
        }

        container.register(GalleryViewModelFactory.self) { c in
            { productID in
                GalleryViewModel(logic: c.resolve(GalleryLogicProtocol.self), productID: productID, router: c.resolve())
            }
        }
    }
}

import AppFoundation
import Foundation

/// Un `CartViewModel` necesita un `userId` en tiempo de ejecución que `Container.resolve()`
/// no puede dar por su cuenta: `RootView` resuelve esta factoría una vez y la llama con el
/// id que trae `AppRoute.cart(userId:)`. Mismo patrón que `GalleryViewModelFactory`.
public typealias CartViewModelFactory = @MainActor (_ userId: Int) -> CartViewModel

/// Registra la feature de carrito. `APIServiceProtocol` (`CoreNetworking`) se resuelve, no
/// se construye aquí: es el pipeline autenticado de la app, que posee `NetworkingModule`.
public struct CartModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(CartServicing.self) { c in
            CartService(api: c.resolve())
        }

        container.register(CartLogicProtocol.self, lifecycle: .transient) { c in
            CartLogic(cartService: c.resolve())
        }

        container.register(CartViewModelFactory.self) { c in
            { userId in
                CartViewModel(logic: c.resolve(CartLogicProtocol.self), userId: userId)
            }
        }
    }
}

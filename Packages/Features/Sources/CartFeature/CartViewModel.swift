import AppFoundation
import Foundation
import Observation

/// Orquesta la pantalla de carrito: pide el carrito del usuario y decide entre contenido,
/// vacío y error. Nunca importa `CoreNetworking` ni referencia `CartService` — solo
/// `logic`.
///
/// `@Observable` no se hereda de `BaseViewModel`: sin él, `cart` no notificaría a SwiftUI
/// (regla R15 del linter).
@Observable
@MainActor
public final class CartViewModel: LogicViewModel<any CartLogicProtocol>, ActionHandling {
    // `nonisolated` a propósito: sin un deinit explícito el compilador sintetiza uno
    // aislado que pasa por un shim de back-deploy en sistemas más viejos que el runtime
    // del toolchain (`docs/repros/isolated-deinit-backdeploy.md` de AppFoundation). Aquí
    // no hay nada que limpiar.
    deinit {}

    /// De quién es el carrito. Viene de `AppRoute.cart(userId:)`, no de una sesión que
    /// esta feature no conoce: ver la decisión de diseño en el proposal del cambio.
    public let userId: Int

    public private(set) var cart: Cart = .empty

    public enum Action: Sendable {
        case load
    }

    public init(logic: any CartLogicProtocol, userId: Int) {
        self.userId = userId
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        }
    }

    private func load() {
        // `.preserveCurrentPhase`: el closure elige entre `.content` y `.empty`; la
        // transición por defecto forzaría `.content` y se comería el `setEmpty()`.
        performLoad(successTransition: .preserveCurrentPhase) { vm in
            do {
                let cart = try await vm.logic.load(userId: vm.userId)
                vm.cart = cart
                if cart.isEmpty { vm.setEmpty() } else { vm.setContent() }
            } catch CartError.cancelled {
                // Lo exige la spec `plataforma`: al reconocer la cancelación,
                // `performLoad` sale con un `return` que no toca `phase`, así que la fase
                // transitoria puesta ANTES se queda puesta y la pantalla se cuelga en
                // `.loading` para siempre. Y solo si esta `Task` sigue viva: `performLoad`
                // cancela la carga anterior al arrancar la nueva, y sin la condición la
                // superada le quitaría el indicador a la que la superó.
                if !Task.isCancelled { vm.setIdle() }
                throw CartError.cancelled
            }
        }
    }
}

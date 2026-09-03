import AppFoundation
import Foundation

/// Registers the Login feature: `LoginLogicProtocol` (built on `AuthServicing` and
/// `SessionStoring`, both already registered by `CoreModule`) and `LoginViewModel`.
/// `CoreModule` must be registered before this one (see `AppStarterApp`'s module list) —
/// laziness means the ORDER of `register(modules:)` doesn't matter for correctness, only
/// that every module is registered before the first `resolve()`.
public struct LoginModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        container.register(LoginLogicProtocol.self) { c in
            LoginLogic(authService: c.resolve(), sessionStore: c.resolve())
        }

        container.register(LoginViewModel.self, lifecycle: .transient) { c in
            LoginViewModel(logic: c.resolve(), router: c.resolve(), sessionState: c.resolve())
        }
    }
}

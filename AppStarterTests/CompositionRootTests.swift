import AppFoundation
import AppStarterKit
import Foundation
import Testing

/// A smoke test for the composition root itself: every `DependencyModule` AppStarter
/// registers at startup (`AppStarterApp.makeModules()`) resolves its `ViewModel` without
/// crashing. The layered unit tests (spies/mocks per protocol, one Logic/Service/Store
/// mapping at a time) live in `AppStarterKit`'s own `AppStarterKitTests` — this target
/// exists to catch the one thing those can't: a DI wiring mistake (a missing
/// registration, a cycle) that only shows up when every module registers together, the
/// way the real app does it.
@Suite("Composition root")
@MainActor
struct CompositionRootTests {
    @Test("Every module resolves its ViewModel without crashing")
    func allModulesResolve() throws {
        let container = Container()
        let modules: [DependencyModule] = [
            CoreModule(baseURL: URL(string: "https://dummyjson.com")!),
            LoginModule(),
            ProductsModule(),
            ProductDetailModule(),
            try FavoritesModule.inMemory(),
            ProfileModule(),
            SearchModule()
        ]
        container.register(modules: modules)

        #expect(container.canResolve(LoginViewModel.self))
        #expect(container.canResolve(ProductsViewModel.self))
        #expect(container.canResolve(ProductDetailViewModelFactory.self))
        #expect(container.canResolve(FavoritesViewModel.self))
        #expect(container.canResolve(ProfileViewModel.self))
        #expect(container.canResolve(SearchViewModel.self))

        _ = container.resolve(LoginViewModel.self)
        _ = container.resolve(ProductsViewModel.self)
        _ = container.resolve(ProductDetailViewModelFactory.self)(1)
        _ = container.resolve(FavoritesViewModel.self)
        _ = container.resolve(ProfileViewModel.self)
        _ = container.resolve(SearchViewModel.self)
    }
}

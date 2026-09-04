import AppFoundation
import FavoritesFeature
import Foundation
import LoginFeature
import Networking
import ProductDetailFeature
import ProductsFeature
import ProfileFeature
import SearchFeature
import Testing

@testable import AppStarter

/// A smoke test for the composition root itself: every `DependencyModule` AppStarter
/// registers at startup (`AppModule.makeModules()`) resolves its `ViewModel` without
/// crashing. The layered unit tests (spies/mocks per protocol, one Logic/Service/Store
/// mapping at a time) live in `Packages/Platform`/`Packages/Features`'s own test targets
/// — this target exists to catch the one thing those can't: a DI wiring mistake (a
/// missing registration, a cycle) that only shows up when every module registers
/// together, the way the real app does it.
///
/// Builds its own module list (mirroring `AppModule.makeModules()`, not calling it
/// directly) so it can force `FavoritesModule.inMemory()` — a native `xcodebuild test`
/// run has no `-UITestOffline` launch argument to trigger that in `AppModule` itself, and
/// this test must never touch a real, on-disk SwiftData store.
@Suite("Composition root")
@MainActor
struct CompositionRootTests {
    @Test("Every module resolves its ViewModel without crashing")
    func allModulesResolve() throws {
        let container = Container()
        let modules: [DependencyModule] = [
            PlatformModule(),
            NetworkingModule(baseURL: URL(string: "https://dummyjson.com")!),
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

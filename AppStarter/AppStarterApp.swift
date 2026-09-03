import AppFoundation
import AppStarterKit
import SwiftUI

/// AppStarter's composition root. `@main` does exactly two things per the architecture
/// (`AppFoundation/AGENTS.md`): register every `DependencyModule` into `Container.shared`
/// once at startup, and install the app-wide `ErrorPresenting`. Nothing past this file
/// constructs a `Logic`/`Service`/`Store` directly — every screen resolves its
/// `ViewModel` from `Container.shared`.
@main
struct AppStarterApp: App {
    init() {
        BaseViewModel.errorPresenter = AppErrorPresenter()
        Container.shared.register(modules: AppStarterApp.makeModules())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    /// `-UITestOffline` (set by `AppStarterUITests`) swaps the real network for
    /// `InMemoryTransport` loaded with recorded DummyJSON responses
    /// (`OfflineFixtures.swift`) — CI runs the UI tests without depending on the real
    /// API being reachable. Every other launch (including a developer running the app,
    /// or the UI tests without that flag) talks to the real `https://dummyjson.com`.
    private static func makeModules() -> [DependencyModule] {
        let baseURL = URL(string: "https://dummyjson.com")!
        let isOffline = ProcessInfo.processInfo.arguments.contains("-UITestOffline")
        let transport = isOffline ? OfflineFixtures.makeTransport() : nil

        // A broken `ModelContainer` at startup is a programmer error (bad schema), not a
        // recoverable runtime condition — `AppFoundation/Examples/CatalogApp` force-tries
        // the same way.
        let favoritesModule: FavoritesModule
        if isOffline {
            favoritesModule = try! FavoritesModule.inMemory()
        } else {
            favoritesModule = try! FavoritesModule()
        }

        return [
            CoreModule(baseURL: baseURL, transport: transport),
            LoginModule(),
            ProductsModule(),
            ProductDetailModule(),
            favoritesModule,
            ProfileModule(),
            SearchModule()
        ]
    }
}

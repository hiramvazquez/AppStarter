import AppFoundation
import SwiftUI

/// AppStarter's composition root. `@main` does exactly two things
/// (`AppFoundation/AGENTS.md`): register every `DependencyModule` into `Container.shared`
/// once at startup, and install the app-wide `ErrorPresenting`. The modules themselves
/// live in `AppModule.swift` — nothing here changes when a feature is added.
@main
struct AppStarterApp: App {
    init() {
        BaseViewModel.errorPresenter = AppErrorPresenter()
        do {
            Container.shared.register(modules: try AppModule.makeModules())
        } catch {
            preconditionFailure("Composition root failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

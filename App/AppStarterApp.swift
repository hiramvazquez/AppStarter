import AppFoundation
import Domain
import Networking
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

        // `Container(parent:)` per session (PRD-APP-02): the only place that can see both
        // `AppSessionState` (`Networking`) and the session-scoped `*Feature` module types
        // it registers on every login — `Networking` itself can't (R13).
        let sessionState = Container.shared.resolve(AppSessionState.self)
        sessionState.makeSessionModules = { AppModule.makeSessionModules() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()  // `.onOpenURL` lives there: it needs the coordinator's root to defer a link
        }
    }
}

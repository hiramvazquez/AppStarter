import AnalyticsAdapters
import AppFoundation
import CameraKit
import CoreNetworking
import DiagnosticsFeature
import Domain
import FavoritesFeature
import Foundation
import LoginFeature
import Networking
import ProductDetailFeature
import ProductsFeature
import ProfileFeature
import SearchFeature
import UploadsFeature

// archinit:imports

/// Composition root (`AppFoundation/AGENTS.md` § generador y linter): assembles every
/// `DependencyModule` AppStarter registers at startup. `PlatformModule` (below) wires
/// navigation, Domain (nothing of its own — pure models/protocols), and every Kit/Adapter
/// `archinit --multi` generated; `NetworkingModule` (`Packages/Platform`, added by hand —
/// not something the kit generates) wires session/auth; `generate-feature` (modo multi)
/// appends `<Name>Module()` right below the marker — nothing above it changes when a
/// feature is added.
enum AppModule {
    /// Base URL every `--api` feature module receives — DummyJSON, this starter's target
    /// API (PRD-APP-01). One place, not one per feature.
    static let apiBaseURL: URL = {
        guard let url = URL(string: "https://dummyjson.com") else { preconditionFailure("Invalid API base URL") }
        return url
    }()

    /// The composition root: every `DependencyModule` the app registers at launch.
    /// `generate-feature` (multi mode) appends each feature's module at the marker, with the
    /// `init` the generated module actually has (`baseURL:`, `try` for SwiftData…).
    ///
    /// `-UITestOffline` (set by `AppUITests`) swaps the real network for
    /// `InMemoryTransport` loaded with recorded DummyJSON responses
    /// (`OfflineFixtures.swift`) — CI runs the UI tests without depending on the real API
    /// being reachable. Every other launch (a developer running the app, or the UI tests
    /// without that flag) talks to the real API.
    @MainActor
    static func makeModules() throws -> [DependencyModule] {
        let isOffline = ProcessInfo.processInfo.arguments.contains("-UITestOffline")
        let transport = isOffline ? OfflineFixtures.makeTransport() : nil

        // A broken `ModelContainer` at startup is a programmer error (bad schema), not a
        // recoverable runtime condition — `AppFoundation/Examples/CatalogApp` force-tries
        // the same way.
        let favoritesModule: FavoritesModule = isOffline ? try FavoritesModule.inMemory() : try FavoritesModule()

        return [
            PlatformModule(),
            NetworkingModule(baseURL: apiBaseURL, transport: transport),
            LoginModule(),
            ProductsModule(),
            ProductDetailModule(),
            favoritesModule,
            SearchModule(),
            DiagnosticsModule(
                baseURL: apiBaseURL,
                offlineTransport: isOffline ? OfflineFixtures.makeDiagnosticsOfflineTransport() : nil
            ),
            UploadsModule()
            // archinit:modules
        ]
    }

    /// Session-scoped modules (PRD-APP-02, `Container(parent:)`): registered by
    /// `AppSessionState.startSession()` into a FRESH child container on every login, not
    /// into `Container.shared` — `RootView` resolves `ProfileViewModel` from
    /// `AppSessionState.sessionContainer`, never from `Container.shared` directly. `Profile`
    /// is the natural first candidate: its `RefreshActivityLog` is genuinely per-session
    /// state (how many times THIS session's token silently refreshed), not app-lifetime
    /// state — `AppStarterApp.init()` wires this closure onto `AppSessionState` right after
    /// registering `makeModules()`, since `Networking` (where `AppSessionState` lives)
    /// cannot import `ProfileFeature` (R13).
    @MainActor
    static func makeSessionModules() -> [DependencyModule] {
        [ProfileModule()]
    }
}

struct PlatformModule: DependencyModule {
    func register(in container: Container) {
        // MARK: Navigation
        container.register(Coordinator<AppRoute>.self) { _ in Coordinator(root: .login) }
        container.register((any Router<AppRoute>).self) { c in c.resolve(Coordinator<AppRoute>.self) }

        // MARK: Kits
        container.register(CameraProviding.self) { _ in CameraKitProvider() }
        container.register(CameraCapturing.self) { _ in CameraKitCapture() }
        // MARK: Adapters
        container.register(AnalyticsTracking.self) { _ in ConsoleAnalyticsAdapter() }
    }
}

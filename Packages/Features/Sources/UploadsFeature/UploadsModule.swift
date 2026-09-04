import AppFoundation
import CoreNetworking
import Domain
import Foundation

/// Registers the Uploads feature.
///
/// **Friction fixed by hand (docs/INFORME-MULTI.md)**: `generate-feature Uploads --api`
/// generated its OWN `container.register(APIServiceProtocol.self) { … APIService(…) }` —
/// correct for a brand-new project with no shared networking wiring yet, but WRONG here:
/// this app already has ONE authenticated `APIServiceProtocol` singleton
/// (`Networking.NetworkingModule`, with the bearer token interceptor and refresh retrier
/// every other feature depends on). Registering a second, unauthenticated one under the
/// SAME container/type would SILENTLY OVERWRITE it (`Container.register`'s documented
/// last-registration-wins behavior) — every feature registered AFTER this module in
/// `AppModule.makeModules()` would lose its bearer token with no compiler error, only a
/// DEBUG-only console warning. Removed; `UploadsService` resolves the EXISTING
/// authenticated service via `c.resolve()`, exactly like every other `--api` feature.
public struct UploadsModule: DependencyModule {
    public init() {}

    public func register(in container: Container) {
        // MARK: Service
        container.register(UploadsServicing.self) { c in
            UploadsService(api: c.resolve())
        }

        // MARK: Logic
        container.register(UploadsLogicProtocol.self) { c in
            UploadsLogic(uploadsService: c.resolve(), camera: c.resolve(), analytics: c.resolve())
        }

        // MARK: ViewModel — resolved by the root view, never constructed by Logic/Service.
        container.register(UploadsViewModel.self, lifecycle: .transient) { c in
            UploadsViewModel(logic: c.resolve())
        }
    }
}

import AppFoundation
import CoreNetworking
import Foundation

/// Registers the Diagnostics feature. `--no-service` (`generate-feature`) left a
/// placeholder `DiagnosticsServicing`; `DiagnosticsService` (`Services/`) is the concrete,
/// hand-written implementation this registers — a minimal Service over the app's own
/// authenticated `APIServiceProtocol` (`Networking`) plus a few deliberately-misconfigured
/// pipelines of its own (PRD-APP-02).
public struct DiagnosticsModule: DependencyModule {
    private let baseURL: URL
    /// `-UITestOffline`'s shared transport, forwarded from `AppModule.makeModules()` —
    /// `nil` in production (real network). Used for the 401/unreachable pipelines this
    /// Service builds itself; the app's authenticated `APIServiceProtocol` (404, timeout,
    /// invalid JSON, the slow request) already respects it via `NetworkingModule`.
    private let offlineTransport: (any HTTPTransport)?

    public init(baseURL: URL, offlineTransport: (any HTTPTransport)? = nil) {
        self.baseURL = baseURL
        self.offlineTransport = offlineTransport
    }

    public func register(in container: Container) {
        container.register(DiagnosticsServicing.self) { [baseURL, offlineTransport] c in
            DiagnosticsService(baseURL: baseURL, authenticatedAPI: c.resolve(), offlineTransport: offlineTransport)
        }

        container.register(DiagnosticsLogicProtocol.self) { c in
            DiagnosticsLogic(diagnosticsService: c.resolve())
        }

        container.register(DiagnosticsViewModel.self, lifecycle: .transient) { c in
            DiagnosticsViewModel(logic: c.resolve())
        }
    }
}

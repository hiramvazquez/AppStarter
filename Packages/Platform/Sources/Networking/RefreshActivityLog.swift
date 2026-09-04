import Foundation
import Observation

/// Records every time the token refresh pipeline (`TokenRefreshRetrier`, wired in
/// `makeAuthenticatedAPIService`) silently renewed the session — what `ProfileFeature`'s
/// `ProfileView` reads to satisfy PRD-APP-01's "muestra el refresh cuando el token
/// caduca" without adding a second, parallel logging system. `@MainActor`/`@Observable`,
/// like every other piece of app-wide state here (`AppSessionState`).
@MainActor
@Observable
public final class RefreshActivityLog {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    public private(set) var refreshCount = 0
    public private(set) var lastRefreshDate: Date?

    public init() {}

    public func recordRefresh(now: Date = Date()) {
        refreshCount += 1
        lastRefreshDate = now
    }
}

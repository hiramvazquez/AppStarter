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
    public private(set) var refreshCount = 0
    public private(set) var lastRefreshDate: Date?

    public init() {}

    public func recordRefresh(now: Date = Date()) {
        refreshCount += 1
        lastRefreshDate = now
    }
}

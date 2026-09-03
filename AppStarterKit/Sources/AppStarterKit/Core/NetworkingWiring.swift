import AppFoundation
import CoreNetworking
import Foundation

/// Thrown by the refresh closure below when there is no stored session to refresh —
/// `TokenRefreshRetrier` never calls it without a prior 401, but a signed-out app calling
/// an authenticated endpoint directly (a bug, not a runtime condition) would hit this.
struct NoStoredSessionToRefresh: Error {}

/// Builds the AUTHENTICATED `APIService` every feature but Login/refresh itself uses:
/// bearer token read fresh from `SessionStoring` on every request, and a retrier that
/// refreshes it (via `AuthServicing`, built on a SEPARATE, unauthenticated `APIService` —
/// see `CoreModule`) and replays the request once on a 401. When the refresh itself fails,
/// the session cannot recover: `sessionStore` is invalidated and `sessionExpiring` is
/// notified, so `RootView` routes back to `.login` with a banner (M6, mirrors
/// `AppFoundation/Examples/LoginApp/Sources/LoginApp/Features/Login/Services/LoginService.swift`).
///
/// This wiring lives in `Core/`, not inside any one feature's `Module`, because it is
/// genuinely cross-feature: every authenticated request in the app goes through the ONE
/// `APIServiceProtocol` this builds.
// Composition root: the seven collaborators are injected explicitly on purpose (DI by init,
// no hidden globals); grouping them in a struct would only move the same seven names.
// swiftlint:disable:next function_parameter_count
func makeAuthenticatedAPIService(
    configuration: NetworkingConfiguration,
    transport: any HTTPTransport,
    authService: any AuthServicing,
    sessionStore: any SessionStoring,
    sessionExpiring: any SessionExpiring,
    refreshLog: RefreshActivityLog,
    refreshExpiresInMinutes: Int,
    clock: any Clock<Duration> = ContinuousClock()
) -> APIService {
    let refresher = TokenRefresher {
        guard let current = await sessionStore.currentSession() else {
            await sessionExpiring.sessionDidExpire()
            throw NoStoredSessionToRefresh()
        }
        do {
            let newTokens = try await authService.refresh(
                refreshToken: current.refreshToken,
                expiresInMinutes: refreshExpiresInMinutes
            )
            await sessionStore.save(
                StoredSession(
                    accessToken: newTokens.accessToken,
                    refreshToken: newTokens.refreshToken,
                    userID: current.userID
                )
            )
            await MainActor.run { refreshLog.recordRefresh() }
        } catch {
            await sessionStore.invalidate()
            await sessionExpiring.sessionDidExpire()
            throw error
        }
    }
    return APIService(
        configuration: configuration,
        transport: transport,
        interceptors: [BearerTokenInterceptor { await sessionStore.currentAccessToken() }],
        retriers: [TokenRefreshRetrier(refresher: refresher)],
        clock: clock
    )
}

import AppFoundation
import Foundation
import Observation

/// Notified when a session can no longer be recovered — a refresh attempt itself failed,
/// not merely one request's 401. Wired into `makeAuthenticatedAPIService` (see
/// `Features/Login/Services/AuthService.swift`); never called directly by a `Logic`.
/// Identical contract to `AppFoundation/Examples/LoginApp`'s `SessionExpiring`.
public protocol SessionExpiring: Sendable {
    func sessionDidExpire() async
}

/// App-wide session state: the piece `RootView` and `LoginViewModel` both observe.
/// `@MainActor`/`@Observable`, like every other piece of visible app state in this
/// architecture (`AppFoundation/Examples/LoginApp/Sources/LoginApp/AppSessionState.swift`
/// is the reference this mirrors).
///
/// `sessionDidExpire()` does two things atomically: routes back to `.login` (global
/// logout, PRD-APP-01 "Al expirar la sesión") and arms `bannerOnNextLogin`, so the FRESH
/// `LoginViewModel` `RootView` resolves for `.login` can show "session expired" once, then
/// clear the flag — a plain boolean instead of a banner queue, because at most one
/// expiry can be pending at a time (the app is single-session).
@MainActor
@Observable
public final class AppSessionState: SessionExpiring {
    /// `Coordinator`, not `any Router<AppRoute>`: `setRoot(_:)` — clear the stack AND any
    /// modal, in one call — is a `Coordinator`-specific method, not part of the `Router`
    /// protocol (which only models push/pop/present/dismiss). This is the one legitimate
    /// reason a piece of this app depends on the concrete navigation type instead of the
    /// protocol.
    private let router: Coordinator<AppRoute>

    /// `true` right after a forced logout; `LoginViewModel` reads it once on appear
    /// (`consumeExpiryBanner()`) to show a banner, then it resets.
    public private(set) var bannerOnNextLogin = false

    public init(router: Coordinator<AppRoute>) {
        self.router = router
    }

    public func sessionDidExpire() async {
        bannerOnNextLogin = true
        router.setRoot(.login)
    }

    /// Called once by `LoginViewModel` on appear. Returns whether a banner should be
    /// shown, and clears the flag so it never repeats on a later, ordinary visit to
    /// `.login` (e.g. after an explicit logout from `Profile`).
    public func consumeExpiryBanner() -> Bool {
        defer { bannerOnNextLogin = false }
        return bannerOnNextLogin
    }
}

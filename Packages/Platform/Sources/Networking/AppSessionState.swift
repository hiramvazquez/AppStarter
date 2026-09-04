import AppFoundation
import Domain
import Foundation
import Observation

/// Notified when a session can no longer be recovered — a refresh attempt itself failed,
/// not merely one request's 401. Wired into `makeAuthenticatedAPIService`
/// (`NetworkingWiring.swift`); never called directly by a `Logic`. Identical contract to
/// `AppFoundation/Examples/LoginApp`'s `SessionExpiring`.
public protocol SessionExpiring: Sendable {
    func sessionDidExpire() async
}

/// App-wide session state: the piece `RootView` (via `AppModule`) and `LoginFeature`'s
/// `LoginViewModel` both observe. `@MainActor`/`@Observable`, like every other piece of
/// visible app state in this architecture
/// (`AppFoundation/Examples/LoginApp/Sources/LoginApp/AppSessionState.swift` is the
/// reference this mirrors).
///
/// Lives in `Networking`, not `Domain`: it holds a concrete `Coordinator<AppRoute>`
/// (`AppFoundation`), and `Domain` only imports `Foundation`. `LoginFeature`'s
/// `LoginViewModel` depends on this CONCRETE type (not a protocol) for
/// `consumeExpiryBanner()` — `Networking` is already an allowed import for `*Feature`
/// (`.archlint.yml`, R13), exactly like `AuthServicing`/`ProductsServicing` above.
///
/// `sessionDidExpire()` does two things atomically: routes back to `.login` (global
/// logout, PRD-APP-01 "Al expirar la sesión") and arms `bannerOnNextLogin`, so the FRESH
/// `LoginViewModel` `RootView` resolves for `.login` can show "session expired" once, then
/// clear the flag — a plain boolean instead of a banner queue, because at most one
/// expiry can be pending at a time (the app is single-session).
///
/// ## `Container(parent:)` per session (PRD-APP-02, Fase 2)
///
/// `sessionContainer` is a CHILD container (`AppFoundation`'s `Container(parent:)`) that
/// exists only between `startSession()` (called by `LoginViewModel` right after a
/// successful login) and the next `endSession()` (a forced expiry, or an explicit
/// logout — `sessionDidEnd()`): whatever a session-scoped `DependencyModule` registers
/// there is released the moment the session ends, because `sessionContainer` itself is
/// replaced by a fresh, empty child — nothing keeps the old one (or its singletons)
/// alive. `RootView` resolves session-scoped feature `ViewModel`s (today: `Profile`, the
/// screen whose `RefreshActivityLog` is genuinely per-session state) from
/// `sessionContainer`, never from `Container.shared` directly.
///
/// `Networking` can't construct a `ProfileModule()` itself (`Networking` doesn't — and
/// must not, R13 — import `*Feature`), so the actual registrations live in a closure the
/// composition root (`App/AppStarterApp.swift`) supplies once, right after
/// `Container.shared.register(modules:)`.
@MainActor
@Observable
public final class AppSessionState: SessionExpiring {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    /// `Coordinator`, not `any Router<AppRoute>`: `setRoot(_:)` — clear the stack AND any
    /// modal, in one call — is a `Coordinator`-specific method, not part of the `Router`
    /// protocol (which only models push/pop/present/dismiss). This is the one legitimate
    /// reason a piece of this app depends on the concrete navigation type instead of the
    /// protocol.
    private let router: Coordinator<AppRoute>

    /// The container every fresh `sessionContainer` is parented to. `Container.shared` in
    /// production; a throwaway `Container()` in tests, so a test never touches the real
    /// global container (`AppSessionStateSessionContainerTests`).
    private let parentContainer: Container

    /// Session-scoped `DependencyModule`s to register into a fresh `sessionContainer` on
    /// every `startSession()` — set once by `App/AppStarterApp.swift` (the only layer that
    /// can see both this type and the `*Feature` module types it registers). `nil` (the
    /// default, and what every test that doesn't care about feature wiring leaves it as)
    /// registers nothing extra: `sessionContainer` still exists and still falls back to
    /// `parentContainer` for anything not registered directly in it.
    public var makeSessionModules: (@MainActor () -> [any DependencyModule])?

    /// `true` right after a forced logout; `LoginViewModel` reads it once on appear
    /// (`consumeExpiryBanner()`) to show a banner, then it resets.
    public private(set) var bannerOnNextLogin = false

    /// The current session's child container. Starts as an empty child of
    /// `parentContainer` (nothing session-scoped resolves until `startSession()` runs);
    /// replaced by a FRESH empty child on every `endSession()` — the previous one, and any
    /// singleton it held, is simply no longer referenced by anything and gets released.
    ///
    /// `@ObservationIgnored` on purpose: `RootView` reads this only inside the `.profile`
    /// case of its route `switch` — a case that already re-runs whenever `route` itself
    /// changes (a `Coordinator<AppRoute>`-tracked, independent property). Tracking it too
    /// would make `RootView.body` reactive to `sessionContainer` on its OWN, so a logout's
    /// `endSession()` (which discards it) could retrigger the STILL-current `.profile` case
    /// a moment before `router.setRoot(.login)` — the `switch` — actually moves off it,
    /// resolving `ProfileViewModel` from an emptied child container and crashing
    /// ("Dependency 'ProfileViewModel' not registered"). Reproduced via `FullFlowTests`
    /// against a real simulator; fixed here, not by reordering `endSession()`/`setRoot()`
    /// (SwiftUI's cross-object Observation batching order isn't a contract to depend on).
    @ObservationIgnored public private(set) var sessionContainer: Container

    public init(router: Coordinator<AppRoute>, parentContainer: Container = .shared) {
        self.router = router
        self.parentContainer = parentContainer
        self.sessionContainer = Container(parent: parentContainer)
    }

    /// Called by `LoginViewModel` right after a successful login: builds a brand new
    /// child container and registers `makeSessionModules()` into it — a fresh
    /// `RefreshActivityLog` (and whatever else a future session-scoped module needs)
    /// every time, never one carried over from a previous session.
    public func startSession() {
        let child = Container(parent: parentContainer)
        child.register(RefreshActivityLog.self) { _ in RefreshActivityLog() }
        if let makeSessionModules {
            child.register(modules: makeSessionModules())
        }
        sessionContainer = child
    }

    public func sessionDidExpire() async {
        bannerOnNextLogin = true
        endSession()
        router.setRoot(.login)
    }

    /// The user's own, explicit logout (`ProfileViewModel`) — same container teardown as
    /// `sessionDidExpire()`, but never arms the "session expired" banner: nothing to warn
    /// about, the user asked for this.
    public func sessionDidEnd() async {
        endSession()
        router.setRoot(.login)
    }

    /// Called once by `LoginViewModel` on appear. Returns whether a banner should be
    /// shown, and clears the flag so it never repeats on a later, ordinary visit to
    /// `.login` (e.g. after an explicit logout from `Profile`).
    public func consumeExpiryBanner() -> Bool {
        defer { bannerOnNextLogin = false }
        return bannerOnNextLogin
    }

    private func endSession() {
        sessionContainer = Container(parent: parentContainer)
    }
}

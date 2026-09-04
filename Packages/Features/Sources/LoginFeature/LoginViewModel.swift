import AppFoundation
import Domain
import Foundation
import Networking
import Observation

/// Orchestrates between `LoginView` and `LoginLogic`: receives an `Action`, calls
/// `logic`, updates `username`/`password`, and moves to `.products` on success. Never
/// imports CoreNetworking, never references `AuthService`/`SessionStore` directly — only
/// `logic`.
///
/// `@Observable` here too — not just the one `AppFoundation.BaseViewModel` already
/// carries (`docs/INFORME-MULTI.md` §11): the macro only instruments stored properties
/// declared IN the class it's attached to, never a subclass's, so `username`/`password`
/// would go untracked without this. PRD-APP-02 tramo B item 0: every ViewModel in this
/// repo declares its own `@Observable`, whether or not today's mutations happen to always
/// ride along with a `phase`/`activity` change (they do here, but that's incidental).
@MainActor
@Observable
public final class LoginViewModel: LogicViewModel<any LoginLogicProtocol>, ActionHandling {
    public private(set) var username = ""
    public private(set) var password = ""

    /// `Coordinator`, not `any Router<AppRoute>` — `setRoot(.products)` on success needs
    /// `Coordinator`'s own API (see `AppSessionState`'s doc comment for why).
    private let router: Coordinator<AppRoute>
    private let sessionState: AppSessionState

    /// Every action `LoginView` recognizes.
    public enum Action: Sendable {
        case appear
        case updateUsername(String)
        case updatePassword(String)
        case login
    }

    public init(logic: any LoginLogicProtocol, router: Coordinator<AppRoute>, sessionState: AppSessionState) {
        self.router = router
        self.sessionState = sessionState
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .appear: appear()
        case .updateUsername(let username): self.username = username
        case .updatePassword(let password): self.password = password
        case .login: login()
        }
    }

    /// A fresh `LoginViewModel` is resolved every time the coordinator routes back to
    /// `.login` (`Container.register(... lifecycle: .transient)`) — including the one
    /// `AppSessionState.sessionDidExpire()` produces after a failed refresh. Consuming the
    /// flag here (once) is what turns that into a one-shot banner instead of a sticky one.
    private func appear() {
        guard sessionState.consumeExpiryBanner() else { return }
        showBanner(.warning("Tu sesión ha caducado. Inicia sesión de nuevo."))
    }

    private func login() {
        performLoad { vm in
            try await vm.logic.login(username: vm.username, password: vm.password)
            // `Container(parent:)` per session (PRD-APP-02): a fresh session-scoped child
            // container from here on, discarded by the next logout/expiry.
            vm.sessionState.startSession()
            vm.router.setRoot(.products)
        }
    }
}

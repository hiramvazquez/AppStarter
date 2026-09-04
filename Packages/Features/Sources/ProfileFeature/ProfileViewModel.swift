import AppFoundation
import Domain
import Foundation
import Networking

/// Orchestrates the profile screen: load `GET /auth/me`, show the token-refresh activity
/// log (PRD-APP-01: "muestra el refresh cuando el token caduca"), and logout. Never
/// imports CoreNetworking, never references `ProfileService`/`SessionStore` directly —
/// only `logic`.
@MainActor
public final class ProfileViewModel: LogicViewModel<any ProfileLogicProtocol>, ActionHandling {
    public private(set) var profile: UserProfile?

    /// Logout goes through `sessionState.sessionDidEnd()` — not `router.setRoot(.login)`
    /// directly — because ending the session also has to discard the session-scoped
    /// child container (`AppSessionState`'s doc comment, PRD-APP-02 `Container(parent:)`).
    private let sessionState: AppSessionState
    private let refreshLog: RefreshActivityLog

    /// `nil` when the pipeline never silently refreshed the token during this session.
    public var refreshCount: Int { refreshLog.refreshCount }
    public var lastRefreshDate: Date? { refreshLog.lastRefreshDate }

    public enum Action: Sendable {
        case load
        /// Shows the confirmation alert (A15) — `.logout` (below) is what actually signs
        /// out. Ending a session is hard to undo mid-task, so it never fires from a bare
        /// tap.
        case logoutRequested
        case logout
    }

    public init(logic: any ProfileLogicProtocol, sessionState: AppSessionState, refreshLog: RefreshActivityLog) {
        self.sessionState = sessionState
        self.refreshLog = refreshLog
        super.init(logic: logic)
    }

    public func handle(_ action: Action) {
        switch action {
        case .load: load()
        case .logoutRequested: requestLogout()
        case .logout: logout()
        }
    }

    private func load() {
        performLoad { vm in
            vm.profile = try await vm.logic.loadProfile()
        }
    }

    private func requestLogout() {
        showAlert(
            .destructive(
                title: "Cerrar sesión",
                message: "Tendrás que volver a iniciar sesión para continuar.",
                confirm: "Cerrar sesión",
                cancel: "Cancelar",
                onConfirm: { [weak self] in self?.handle(.logout) }
            )
        )
    }

    private func logout() {
        performActivity(errorHandling: .silent) { vm in
            await vm.logic.logout()
            await vm.sessionState.sessionDidEnd()
        }
    }
}

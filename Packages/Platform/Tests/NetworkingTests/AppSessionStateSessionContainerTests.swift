import AppFoundation
import Domain
import Foundation
import Testing

@testable import Networking

/// `AppSessionState.sessionContainer` — `Container(parent:)` per session
/// (PRD-APP-02, Fase 2, escaparate de `Container`). A CHILD container is created fresh on
/// every `startSession()` and discarded (replaced by a new, empty one) on every
/// `endSession()` path (`sessionDidExpire()`, `sessionDidEnd()`) — nothing registered in
/// the old one, singletons included, survives past that point.
///
/// `parentContainer: Container()` (never `.shared`, AppFoundation's real global) keeps
/// this test fully isolated: nothing here touches or depends on app-wide state.
@Suite("AppSessionState — Container(parent:) per session")
@MainActor
struct AppSessionStateSessionContainerTests {
    @Test("startSession() registers a fresh RefreshActivityLog every time — not shared across sessions")
    func startSessionGivesEachSessionItsOwnRefreshActivityLog() {
        let root = Container()
        let sessionState = AppSessionState(router: Coordinator(root: .login), parentContainer: root)

        sessionState.startSession()
        let firstLog = sessionState.sessionContainer.resolve(RefreshActivityLog.self)
        firstLog.recordRefresh(now: Date(timeIntervalSince1970: 1))
        #expect(firstLog.refreshCount == 1)

        sessionState.startSession()
        let secondLog = sessionState.sessionContainer.resolve(RefreshActivityLog.self)

        #expect(secondLog !== firstLog)
        #expect(secondLog.refreshCount == 0)
    }

    @Test("A logout (sessionDidEnd) discards the session container — a singleton registered in it does not survive")
    func sessionDidEndDiscardsSessionScopedSingleton() async {
        let root = Container()
        let sessionState = AppSessionState(router: Coordinator(root: .login), parentContainer: root)

        sessionState.startSession()
        let logBeforeLogout = sessionState.sessionContainer.resolve(RefreshActivityLog.self)
        logBeforeLogout.recordRefresh()

        await sessionState.sessionDidEnd()

        // A fresh login (a new session) resolves a NEW RefreshActivityLog: the one from
        // the ended session is gone, not merely reset.
        sessionState.startSession()
        let logAfterNewLogin = sessionState.sessionContainer.resolve(RefreshActivityLog.self)

        #expect(logAfterNewLogin !== logBeforeLogout)
        #expect(logAfterNewLogin.refreshCount == 0)
    }

    @Test("A forced expiry (sessionDidExpire) discards the session container the same way, and arms the banner")
    func sessionDidExpireDiscardsSessionContainerAndArmsBanner() async {
        let root = Container()
        let sessionState = AppSessionState(router: Coordinator(root: .login), parentContainer: root)
        sessionState.startSession()
        let containerBeforeExpiry = sessionState.sessionContainer

        await sessionState.sessionDidExpire()

        #expect(sessionState.sessionContainer !== containerBeforeExpiry)
        #expect(sessionState.consumeExpiryBanner())
    }

    @Test("makeSessionModules, when set, registers into the fresh child on every startSession()")
    func makeSessionModulesRegistersIntoEveryFreshChild() {
        let root = Container()
        let sessionState = AppSessionState(router: Coordinator(root: .login), parentContainer: root)
        sessionState.makeSessionModules = { [ProbeModule()] }

        sessionState.startSession()

        #expect(sessionState.sessionContainer.canResolve(ProbeMarker.self))
    }

    @Test("A fresh AppSessionState's sessionContainer still resolves through the parent chain")
    func freshSessionContainerFallsBackToParent() {
        let root = Container()
        root.register(instance: "parent-value", as: String.self)
        let sessionState = AppSessionState(router: Coordinator(root: .login), parentContainer: root)

        // Before any startSession() call, sessionContainer is an EMPTY child — it still
        // sees the parent's registrations (Container(parent:)'s whole point), it just has
        // no session-scoped registrations of its own yet.
        #expect(sessionState.sessionContainer.resolve(String.self) == "parent-value")
    }
}

// MARK: - Test-only module/marker for the makeSessionModules test

private struct ProbeMarker {}

private struct ProbeModule: DependencyModule {
    func register(in container: Container) {
        container.register(ProbeMarker.self) { _ in ProbeMarker() }
    }
}

import CoreNetworking
import Foundation
import Testing

@testable import AppStarterKit

/// `LoginLogic` tested against `AuthServiceMock`/`SessionStoreSpy` — no real network, no
/// `LoginViewModel` involved.
@Suite("LoginLogic")
struct LoginLogicTests {
    @Test("An empty username throws .emptyUsername before calling the service")
    func emptyUsernameShortCircuits() async {
        let service = AuthServiceMock()
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: service, sessionStore: sessionStore)

        await #expect(throws: LoginError.emptyUsername) {
            try await logic.login(username: "", password: "emilyspass")
        }
        #expect(await service.loginCalls.calls.isEmpty)
    }

    @Test("An empty password throws .emptyPassword before calling the service")
    func emptyPasswordShortCircuits() async {
        let service = AuthServiceMock()
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: service, sessionStore: sessionStore)

        await #expect(throws: LoginError.emptyPassword) {
            try await logic.login(username: "emilys", password: "")
        }
        #expect(await service.loginCalls.calls.isEmpty)
    }

    @Test("A successful login persists the session")
    func successPersistsSession() async throws {
        let service = AuthServiceMock()
        service.sessionToReturn = AuthSession(tokens: AuthTokens(accessToken: "a", refreshToken: "r"), userID: 42)
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: service, sessionStore: sessionStore)

        try await logic.login(username: "emilys", password: "emilyspass")

        let saved = await sessionStore.savedSessions.calls
        #expect(saved == [StoredSession(accessToken: "a", refreshToken: "r", userID: 42)])
    }

    @Test("A 400 (client) service failure maps to LoginError.invalidCredentials — DummyJSON's real status for bad credentials")
    func clientFailureMapsToInvalidCredentials() async {
        let service = AuthServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 400)
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: service, sessionStore: sessionStore)

        await #expect(throws: LoginError.invalidCredentials) {
            try await logic.login(username: "emilys", password: "wrong")
        }
    }

    @Test("An offline service failure maps to LoginError.offline")
    func offlineFailureMapsToOffline() async {
        let service = AuthServiceMock()
        service.errorToThrow = .stub(code: .transport, underlying: URLError(.notConnectedToInternet))
        let sessionStore = SessionStoreSpy()
        let logic = LoginLogic(authService: service, sessionStore: sessionStore)

        await #expect(throws: LoginError.offline) {
            try await logic.login(username: "emilys", password: "emilyspass")
        }
    }
}

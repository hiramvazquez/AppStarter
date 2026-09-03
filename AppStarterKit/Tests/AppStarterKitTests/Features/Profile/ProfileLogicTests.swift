import CoreNetworking
import Foundation
import Testing

@testable import AppStarterKit

@Suite("ProfileLogic")
struct ProfileLogicTests {
    @Test("loadProfile() returns what the service returns")
    func loadProfileReturnsServiceResult() async throws {
        let service = ProfileServiceMock()
        let sessionStore = SessionStoreSpy()
        let logic = ProfileLogic(profileService: service, sessionStore: sessionStore)

        let profile = try await logic.loadProfile()

        #expect(profile == service.profileToReturn)
    }

    @Test("logout() invalidates the session store")
    func logoutInvalidatesSessionStore() async {
        let service = ProfileServiceMock()
        let sessionStore = SessionStoreSpy(
            sessionToReturn: StoredSession(accessToken: "a", refreshToken: "r", userID: 1)
        )
        let logic = ProfileLogic(profileService: service, sessionStore: sessionStore)

        await logic.logout()

        #expect(await sessionStore.currentSession() == nil)
    }

    @Test("A 401 service failure maps to ProfileError.unauthorized")
    func unauthorizedFailureMaps() async {
        let service = ProfileServiceMock()
        service.errorToThrow = .stub(code: .httpStatus, statusCode: 401)
        let sessionStore = SessionStoreSpy()
        let logic = ProfileLogic(profileService: service, sessionStore: sessionStore)

        await #expect(throws: ProfileError.unauthorized) {
            try await logic.loadProfile()
        }
    }
}

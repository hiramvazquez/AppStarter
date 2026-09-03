import AppFoundationTestSupport
import CoreNetworking
import Foundation

@testable import AppStarterKit

/// Stub that substitutes `AuthServicing` in `LoginLogicTests` — `LoginLogic` under test
/// never makes a real network call.
///
/// `@unchecked Sendable` JUSTIFICADO: a single test configures `sessionToReturn`/
/// `errorToThrow` before exercising the logic under test and never mutates them
/// concurrently with a read — same pattern `MockAPIService` (CoreNetworkingTestSupport)
/// uses for its own stub state.
final class AuthServiceMock: AuthServicing, @unchecked Sendable {
    let loginCalls = SpyRecorder<String>()
    var sessionToReturn = AuthSession(tokens: AuthTokens(accessToken: "access", refreshToken: "refresh"), userID: 1)
    var errorToThrow: APIError?

    func login(username: String, password: String, expiresInMinutes: Int) async throws(APIError) -> AuthSession {
        await loginCalls.record(username)
        if let errorToThrow { throw errorToThrow }
        return sessionToReturn
    }

    func refresh(refreshToken: String, expiresInMinutes: Int) async throws(APIError) -> AuthTokens {
        if let errorToThrow { throw errorToThrow }
        return sessionToReturn.tokens
    }
}

import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

/// Spy that substitutes `LoginLogicProtocol` in `LoginViewModelTests` — the ViewModel
/// under test never touches a real `LoginLogic`.
final class LoginLogicMock: LoginLogicProtocol {
    let logins = SpyRecorder<String>()
    var errorToThrow: (any Error)?

    func login(username: String, password: String) async throws {
        await logins.record(username)
        if let errorToThrow { throw errorToThrow }
    }
}

import AppFoundationTestSupport
import Foundation

@testable import LoginFeature

/// Spy that substitutes `LoginLogicProtocol` in `LoginViewModelTests` — the ViewModel
/// under test never touches a real `LoginLogic`.
final class LoginLogicMock: LoginLogicProtocol {
    let logins = SpyRecorder<String>()
    var errorToThrow: (any Error)?

    private(set) var loginCallCount = 0

    /// Deja parada una llamada concreta. Recibe el número de llamada (1, 2, …) para poder
    /// soltar UNA y dejar la otra en vuelo, que es lo que hace falta para observar qué le pasa
    /// a la fase cuando un login supera a otro. Mismo mecanismo que `CartLogicMock`.
    var gate: (@Sendable (Int) async -> Void)?

    func login(username: String, password: String) async throws {
        loginCallCount += 1
        let llamada = loginCallCount
        await logins.record(username)
        await gate?(llamada)
        if let errorToThrow { throw errorToThrow }
    }
}

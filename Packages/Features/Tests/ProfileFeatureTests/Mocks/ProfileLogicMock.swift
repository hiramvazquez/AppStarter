import AppFoundationTestSupport
import Domain
import Foundation

@testable import ProfileFeature

final class ProfileLogicMock: ProfileLogicProtocol {
    let logoutCalls = SpyRecorder<Void>()
    var profileToReturn = UserProfile(
        id: 1,
        username: "emilys",
        email: "e@x.com",
        firstName: "Emily",
        lastName: "Johnson",
        imageURL: nil
    )
    var errorToThrow: (any Error)?

    private(set) var loadCallCount = 0

    /// Deja parada una llamada concreta. Recibe el número de llamada (1, 2, …) para poder
    /// soltar UNA y dejar la otra en vuelo, que es lo que hace falta para observar qué le pasa
    /// a la fase cuando una carga supera a otra. Mismo mecanismo que `CartLogicMock`.
    var gate: (@Sendable (Int) async -> Void)?

    func loadProfile() async throws -> UserProfile {
        loadCallCount += 1
        let llamada = loadCallCount
        await gate?(llamada)
        if let errorToThrow { throw errorToThrow }
        return profileToReturn
    }

    func logout() async {
        await logoutCalls.record()
    }
}

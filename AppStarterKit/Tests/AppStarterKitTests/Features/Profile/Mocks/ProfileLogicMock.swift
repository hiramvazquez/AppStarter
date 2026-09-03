import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

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

    func loadProfile() async throws -> UserProfile {
        if let errorToThrow { throw errorToThrow }
        return profileToReturn
    }

    func logout() async {
        await logoutCalls.record()
    }
}

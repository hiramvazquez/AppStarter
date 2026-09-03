import CoreNetworking
import Foundation

@testable import AppStarterKit

/// `@unchecked Sendable` JUSTIFICADO: same as `AuthServiceMock` — configured once before
/// exercising the logic under test.
final class ProfileServiceMock: ProfileServicing, @unchecked Sendable {
    var profileToReturn = UserProfile(
        id: 1,
        username: "emilys",
        email: "e@x.com",
        firstName: "Emily",
        lastName: "Johnson",
        imageURL: nil
    )
    var errorToThrow: APIError?

    func me() async throws(APIError) -> UserProfile {
        if let errorToThrow { throw errorToThrow }
        return profileToReturn
    }
}

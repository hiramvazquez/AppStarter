import CoreNetworking
import Foundation

// MARK: - The request / response DTO (M2: only this file ever sees it)

struct GetMeRequest: BaseRequest {
    struct Response: Decodable, Sendable {
        let id: Int
        let username: String
        let email: String
        let firstName: String
        let lastName: String
        let image: String
    }

    let path = "/auth/me"
    let method = HTTPMethod.get
}

// MARK: - The service

/// One API call: `GET /auth/me` (Bearer, added automatically by the authenticated
/// `APIServiceProtocol`'s `BearerTokenInterceptor` — this service never touches the
/// token itself) → `UserProfile`.
public protocol ProfileServicing: Sendable {
    func me() async throws(APIError) -> UserProfile
}

/// The ONLY type in this app that references `APIServiceProtocol`/`BaseRequest` for
/// `/auth/me`.
public struct ProfileService: ProfileServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func me() async throws(APIError) -> UserProfile {
        let response = try await call(GetMeRequest())
        return UserProfile(
            id: response.id,
            username: response.username,
            email: response.email,
            firstName: response.firstName,
            lastName: response.lastName,
            imageURL: URL(string: response.image)
        )
    }
}

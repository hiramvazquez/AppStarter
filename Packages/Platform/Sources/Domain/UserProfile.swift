import Foundation

/// `Sendable`/`Equatable` — never the network `DTO` (M2), see
/// `ProfileFeature/Services/ProfileService.swift`. Only `ProfileFeature` produces one
/// today, but it lives in `Domain` (not `ProfileFeature`) on the same reasoning as
/// `Product`: a model any feature could come to depend on belongs to the shared
/// vocabulary, not to the one feature that happens to fetch it first.
public nonisolated struct UserProfile: Sendable, Equatable {
    public let id: Int
    public let username: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let imageURL: URL?

    public init(id: Int, username: String, email: String, firstName: String, lastName: String, imageURL: URL?) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.imageURL = imageURL
    }
}

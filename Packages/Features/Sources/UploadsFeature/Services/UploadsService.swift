import CoreNetworking
import Foundation

// MARK: - The request / response DTOs (M2: only Services/*.swift and its own tests see them)

/// `POST /products/add`: DummyJSON doesn't persist anything, but echoes back whatever it
/// was sent plus a fresh `id` — exactly enough to show "the upload worked" (PRD-APP-02).
/// No declared `Body`: the photo goes through `upload(_:data:progress:)`'s `data:`
/// parameter instead (see `UploadsService.addProduct`), not this type's `body`.
///
/// Not `private` (unlike `UploadPayload` below): `UploadsServiceTests` (a different file,
/// `@testable import`) stubs `MockAPIService` by REQUEST TYPE — a `private` (file-scoped)
/// declaration would be invisible there, forcing the test to stub a different type than
/// the one this Service actually calls (silently never matching). Same visibility every
/// other feature's own request DTOs already use (`ProfileService.swift`'s `GetMeRequest`,
/// unmarked — internal is the right default, not `private`, when a Service has tests in
/// a sibling file).
struct AddProductRequest: BaseRequest {
    struct Response: Decodable, Sendable, Equatable {
        let id: Int
        let title: String
    }

    let path = "/products/add"
    let method = HTTPMethod.post
}

/// What actually goes over the wire as `upload`'s `data:` — a plain JSON object, not a
/// multipart file: DummyJSON accepts (and echoes) an arbitrary JSON body, so the photo
/// travels as a base64 string field in it (PRD-APP-02: "la foto se manda como parte del
/// body (base64 en el JSON)").
private struct UploadPayload: Encodable, Sendable {
    let title: String
    let photoBase64: String
}

// MARK: - The service

/// One API call — `POST /products/add`, uploaded (not merely `execute`d, PRD-APP-02) with
/// real progress reporting — mapped to `UploadedProduct` (`Domain`-safe, never the DTO).
public protocol UploadsServicing: Sendable {
    func addProduct(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(APIError) -> UploadedProduct
}

/// The ONLY type in this app that references `APIServiceProtocol`/`BaseRequest`/
/// `upload(_:data:progress:)` for `/products/add`.
public struct UploadsService: UploadsServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func addProduct(
        title: String,
        photoData: Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(APIError) -> UploadedProduct {
        let payload = UploadPayload(title: title, photoBase64: photoData.base64EncodedString())
        let body: Data
        do {
            body = try JSONEncoder().encode(payload)
        } catch {
            throw APIError(code: .encoding, underlying: error)
        }

        let response = try await api.upload(AddProductRequest(), data: body, progress: progress)
        return UploadedProduct(id: response.id, title: response.title)
    }
}

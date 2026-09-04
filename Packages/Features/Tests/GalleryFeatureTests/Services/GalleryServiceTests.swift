import CoreNetworking
import CoreNetworkingTestSupport
import Domain
import Foundation
import Testing

@testable import GalleryFeatureCore

/// `GalleryService` — the only type in this feature that touches `APIServiceProtocol` —
/// tested against `MockAPIService`.
@Suite("GalleryService")
struct GalleryServiceTests {
    @Test("A stubbed 200 decodes the DTO into a domain Product with its images")
    func stubbedSuccessDecodesProduct() async throws {
        let mock = MockAPIService()
        mock.stub(
            GetGalleryProductRequest.self,
            returning: GetGalleryProductRequest.DTO(
                id: 3,
                title: "Robot Bear",
                description: "d",
                price: 9.99,
                rating: 4.2,
                thumbnail: "https://cdn.dummyjson.com/thumb.png",
                images: ["https://cdn.dummyjson.com/a.png", "https://cdn.dummyjson.com/b.png"]
            )
        )
        let service = GalleryService(api: mock)

        let product = try await service.fetchProduct(id: 3)

        #expect(product.title == "Robot Bear")
        #expect(
            product.images == [
                URL(string: "https://cdn.dummyjson.com/a.png")!,
                URL(string: "https://cdn.dummyjson.com/b.png")!
            ]
        )
    }

    @Test("A DTO with no images decodes to an empty array, not a decoding failure")
    func stubbedSuccessWithoutImagesDecodesEmpty() async throws {
        let mock = MockAPIService()
        mock.stub(
            GetGalleryProductRequest.self,
            returning: GetGalleryProductRequest.DTO(
                id: 3,
                title: "Robot Bear",
                description: "d",
                price: 9.99,
                rating: 4.2,
                thumbnail: "https://cdn.dummyjson.com/thumb.png",
                images: nil
            )
        )
        let service = GalleryService(api: mock)

        let product = try await service.fetchProduct(id: 3)

        #expect(product.images.isEmpty)
    }

    @Test("A stubbed failure propagates as APIError")
    func stubbedFailurePropagates() async {
        let mock = MockAPIService()
        mock.stub(GetGalleryProductRequest.self, throwing: .stub(code: .httpStatus, statusCode: 404))
        let service = GalleryService(api: mock)

        do {
            _ = try await service.fetchProduct(id: 3)
            Issue.record("Expected fetchProduct(id:) to throw")
        } catch {
            #expect(error.statusCode == 404)
        }
    }
}

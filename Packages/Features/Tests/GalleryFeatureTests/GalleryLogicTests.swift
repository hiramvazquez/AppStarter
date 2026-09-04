import CoreNetworking
import Domain
import Foundation
import Testing

@testable import GalleryFeatureCore

@Suite("GalleryLogic")
struct GalleryLogicTests {
    @Test("load(productID:) maps the service's product into a GalleryState")
    func loadReturnsServiceProduct() async throws {
        let product = Product(
            id: 3,
            title: "Robot Bear",
            description: "d",
            price: 1,
            rating: 1,
            thumbnailURL: nil,
            images: [URL(string: "https://cdn.dummyjson.com/a.png")!, URL(string: "https://cdn.dummyjson.com/b.png")!]
        )
        let service = GalleryServiceMock(result: .success(product))
        let logic = GalleryLogic(galleryService: service)

        let state = try await logic.load(productID: 3)

        #expect(state.title == "Robot Bear")
        #expect(state.images == product.images)
        #expect(await service.fetchCalls.calls == [3])
    }

    @Test("An offline service failure maps to GalleryError.offline")
    func offlineFailureMapsToDomainError() async {
        let service = GalleryServiceMock(
            result: .failure(.stub(code: .transport, underlying: URLError(.notConnectedToInternet)))
        )
        let logic = GalleryLogic(galleryService: service)

        await #expect(throws: GalleryError.offline) {
            _ = try await logic.load(productID: 3)
        }
    }

    @Test("A 404 service failure maps to GalleryError.notFound")
    func notFoundFailureMapsToDomainError() async {
        let service = GalleryServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 404)))
        let logic = GalleryLogic(galleryService: service)

        await #expect(throws: GalleryError.notFound) {
            _ = try await logic.load(productID: 3)
        }
    }

    @Test("A 5xx service failure maps to GalleryError.server")
    func serverFailureMapsToDomainError() async {
        let service = GalleryServiceMock(result: .failure(.stub(code: .httpStatus, statusCode: 503)))
        let logic = GalleryLogic(galleryService: service)

        await #expect(throws: GalleryError.server) {
            _ = try await logic.load(productID: 3)
        }
    }

    @Test("prefetchImage(url:) delegates to the service and never throws")
    func prefetchDelegatesToService() async {
        let service = GalleryServiceMock()
        let logic = GalleryLogic(galleryService: service)
        let url = URL(string: "https://cdn.dummyjson.com/next.png")!

        await logic.prefetchImage(url: url)

        #expect(await service.prefetchCalls.calls == [url])
    }
}

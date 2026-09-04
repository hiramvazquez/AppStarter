import AppFoundationTestSupport
import CoreNetworking
import Domain
import Foundation

@testable import GalleryFeatureCore

/// Spy that substitutes `GalleryServicing` in `GalleryLogicTests` — the Logic under test
/// never touches `APIServiceProtocol`/a real network.
///
/// `actor` (M5): a `Servicing` conformance is `Sendable`, and an actor is the direct way
/// to hold mutable stub state behind that requirement.
actor GalleryServiceMock: GalleryServicing {
    let fetchCalls = SpyRecorder<Int>()
    let prefetchCalls = SpyRecorder<URL>()
    private var result: Result<Product, APIError>

    init(result: Result<Product, APIError> = .failure(.stub(code: .unexpected))) {
        self.result = result
    }

    func fetchProduct(id: Int) async throws(APIError) -> Product {
        await fetchCalls.record(id)
        switch result {
        case .success(let product): return product
        case .failure(let error): throw error
        }
    }

    func prefetchImage(url: URL) async {
        await prefetchCalls.record(url)
    }
}

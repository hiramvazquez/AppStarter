import CoreNetworking
import Domain
import Foundation

// MARK: - The request / response DTOs (M2: only this file ever sees them)

/// Same endpoint `ProductDetail` fetches (`GET /products/{id}`) — a deliberate,
/// standalone `--api` Service (PRD-APP-02, `generate-feature Gallery --api --module`,
/// no `--service-from Products`): Gallery only needs `images`, and re-fetching the
/// product independently keeps this feature decoupled from `Networking`'s shared
/// `ProductsServicing`, which `ProductsFeature`/`ProductDetailFeature`/`SearchFeature`
/// already depend on. `DTO` mirrors `ProductsFeature/Services/ProductsService.swift`'s
/// own — duplicated on purpose (M2: a Service's DTOs never leave its file), not shared.
struct GetGalleryProductRequest: BaseRequest {
    struct DTO: Decodable, Sendable {
        let id: Int
        let title: String
        let description: String
        let price: Double
        let rating: Double
        let thumbnail: String
        /// Absent on some hand-built fixtures — decoded as `[]` rather than failing.
        let images: [String]?
    }
    typealias Response = DTO

    let productID: Int
    var path: String { "/products/\(productID)" }
    let method = HTTPMethod.get

    init(productID: Int) {
        self.productID = productID
    }
}

// MARK: - The service

/// The ONLY type in this feature that references `APIServiceProtocol`/`BaseRequest`.
/// Returns `Product` (`Domain`, already shared by four other features) — never a new,
/// Gallery-specific model, since the domain concept (a product's images) already lives
/// there (PRD-APP-02 groundwork commit).
public protocol GalleryServicing: Sendable {
    func fetchProduct(id: Int) async throws(APIError) -> Product

    /// Warms the URL cache for the next image before the user swipes to it
    /// (`GalleryViewModel`'s `Throttler`-gated prefetch). Best-effort: a failed prefetch
    /// is invisible to the user — `AsyncImage` will simply fetch it again, uncached, when
    /// they actually swipe there. Not part of the app's typed `APIServiceProtocol`
    /// pipeline (no `BaseRequest`/`APIError`/decoding involved) — plain `URLSession`,
    /// the same one `AsyncImage` itself uses (`.shared`), so a successful prefetch's
    /// response sits in `URLCache.shared` by the time the image view asks for it.
    func prefetchImage(url: URL) async
}

public struct GalleryService: GalleryServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func fetchProduct(id: Int) async throws(APIError) -> Product {
        let dto = try await call(GetGalleryProductRequest(productID: id))
        return Product(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            price: dto.price,
            rating: dto.rating,
            thumbnailURL: URL(string: dto.thumbnail),
            images: (dto.images ?? []).compactMap(URL.init(string:))
        )
    }

    public func prefetchImage(url: URL) async {
        _ = try? await URLSession.shared.data(from: url)
    }
}

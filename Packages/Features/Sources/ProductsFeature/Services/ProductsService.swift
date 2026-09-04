import CoreNetworking
import Domain
import Foundation
import Networking

// MARK: - The request / response DTOs (M2: only this file ever sees them)

struct GetProductsRequest: BaseRequest {
    struct DTO: Decodable, Sendable {
        let id: Int
        let title: String
        let description: String
        let price: Double
        let rating: Double
        let thumbnail: String
        /// Absent on some hand-built fixtures (`App/OfflineFixtures.swift`'s older
        /// entries) — decoded (and defaulted, for the memberwise `init` existing tests
        /// use) as `nil`/`[]` rather than failing the whole product.
        let images: [String]?

        init(
            id: Int,
            title: String,
            description: String,
            price: Double,
            rating: Double,
            thumbnail: String,
            images: [String]? = nil
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.price = price
            self.rating = rating
            self.thumbnail = thumbnail
            self.images = images
        }
    }

    struct Response: Decodable, Sendable {
        let products: [DTO]
        let total: Int
        let skip: Int
        let limit: Int
    }

    let path = "/products"
    let method = HTTPMethod.get
    let queryItems: [URLQueryItem]

    init(limit: Int, skip: Int) {
        self.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "skip", value: String(skip))
        ]
    }
}

struct GetProductRequest: BaseRequest {
    typealias Response = GetProductsRequest.DTO

    let productID: Int
    var path: String { "/products/\(productID)" }
    let method = HTTPMethod.get

    init(productID: Int) {
        self.productID = productID
    }
}

struct SearchProductsRequest: BaseRequest {
    struct Response: Decodable, Sendable {
        let products: [GetProductsRequest.DTO]
    }

    let path = "/products/search"
    let method = HTTPMethod.get
    let queryItems: [URLQueryItem]

    init(query: String) {
        self.queryItems = [URLQueryItem(name: "q", value: query)]
    }
}

// MARK: - The service

/// The ONLY type in this app that references `APIServiceProtocol`/`BaseRequest` for
/// `/products*`. `ProductsServicing` (the protocol) lives in `Networking`, not here —
/// `ProductDetailFeature` and `SearchFeature` depend on it too, resolved from the
/// `Container` (`ProductsModule` is the only one that registers it).
public struct ProductsService: ProductsServicing, EndpointService {
    public let api: any APIServiceProtocol

    public init(api: any APIServiceProtocol) {
        self.api = api
    }

    public func fetchProducts(limit: Int, skip: Int) async throws(APIError) -> ProductsPage {
        let response = try await call(GetProductsRequest(limit: limit, skip: skip))
        return ProductsPage(
            items: response.products.map(Self.map),
            total: response.total,
            skip: response.skip,
            limit: response.limit
        )
    }

    public func fetchProduct(id: Int) async throws(APIError) -> Product {
        Self.map(try await call(GetProductRequest(productID: id)))
    }

    public func search(query: String) async throws(APIError) -> [Product] {
        let response = try await call(SearchProductsRequest(query: query))
        return response.products.map(Self.map)
    }

    private static func map(_ dto: GetProductsRequest.DTO) -> Product {
        Product(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            price: dto.price,
            rating: dto.rating,
            thumbnailURL: URL(string: dto.thumbnail),
            images: (dto.images ?? []).compactMap(URL.init(string:))
        )
    }
}

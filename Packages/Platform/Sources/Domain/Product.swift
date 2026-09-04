import Foundation

/// What every screen that shows a product renders — `Products`, `ProductDetail`,
/// `Search`, `Favorites`, `Gallery`. `Sendable`/`Equatable`/`Identifiable`, never the
/// network `DTO` (M2) — see `ProductsFeature/Services/ProductsService.swift`. Shared by
/// five features: lives in `Domain` (`AGENTS.md` § Módulos de este proyecto), not in any
/// one of them.
public nonisolated struct Product: Sendable, Equatable, Hashable, Identifiable {
    public let id: Int
    public let title: String
    public let description: String
    public let price: Double
    public let rating: Double
    public let thumbnailURL: URL?
    /// The full-size gallery images DummyJSON's `GET /products`/`GET /products/{id}` both
    /// return (PRD-APP-02, `Gallery`) — never empty on a real response, but a fixture or a
    /// hand-built `Product` may still omit it, hence the default `[]`.
    public let images: [URL]

    public init(
        id: Int,
        title: String,
        description: String,
        price: Double,
        rating: Double,
        thumbnailURL: URL?,
        images: [URL] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.rating = rating
        self.thumbnailURL = thumbnailURL
        self.images = images
    }
}

/// One page of `GET /products`. Shared by `ProductsFeature` (the only feature that
/// requests pages) and nothing else — kept in `Domain` next to `Product` rather than
/// inside `ProductsFeature` because `Product` itself must live here.
public nonisolated struct ProductsPage: Sendable, Equatable {
    public let items: [Product]
    public let total: Int
    public let skip: Int
    public let limit: Int

    public init(items: [Product], total: Int, skip: Int, limit: Int) {
        self.items = items
        self.total = total
        self.skip = skip
        self.limit = limit
    }

    /// Whether there are more products beyond this page.
    public var hasMore: Bool { skip + items.count < total }
}

import Foundation
import SwiftData

// MARK: - The persistence model (M2: only this file ever sees it)

/// The SwiftData entity. Never leaves this file: `SwiftDataFavoritesStore` maps it to
/// `Product` (the domain model, `Features/Products/ProductsLogic.swift`) on the way out.
@Model
final class FavoriteProductRecord {
    @Attribute(.unique) var id: Int
    var title: String
    var productDescription: String
    var price: Double
    var rating: Double
    var thumbnailURLString: String?

    init(id: Int, title: String, productDescription: String, price: Double, rating: Double, thumbnailURLString: String?) {
        self.id = id
        self.title = title
        self.productDescription = productDescription
        self.price = price
        self.rating = rating
        self.thumbnailURLString = thumbnailURLString
    }
}

// MARK: - The store

/// The local favorites cache. Shared by TWO features: `ProductDetail` (toggles a single
/// product's favorite state) and `Favorites` (lists everything favorited) both depend on
/// `any FavoritesStoring` through `init` — never on `SwiftDataFavoritesStore` directly.
public protocol FavoritesStoring: Sendable {
    func isFavorite(id: Int) async -> Bool

    /// Adds `product` if it isn't already favorited, removes it if it is.
    /// - Returns: The resulting favorite state (`true` = now favorited).
    @discardableResult
    func toggle(_ product: Product) async throws -> Bool

    func fetchAll() async throws -> [Product]

    func remove(id: Int) async throws
}

/// The `FavoritesStoring` AppStarter runs with. `@ModelActor` (M5 — SwiftData's
/// `ModelContext` is not `Sendable` and its initializer is main-actor-isolated, same
/// reasoning as `AppFoundation/Examples/CatalogApp`'s `SwiftDataCatalogStore`).
@ModelActor
public actor SwiftDataFavoritesStore: FavoritesStoring {
    public func isFavorite(id: Int) async -> Bool {
        (try? fetchRecord(id: id)) != nil
    }

    @discardableResult
    public func toggle(_ product: Product) async throws -> Bool {
        if let existing = try fetchRecord(id: product.id) {
            modelContext.delete(existing)
            try modelContext.save()
            return false
        }
        modelContext.insert(
            FavoriteProductRecord(
                id: product.id,
                title: product.title,
                productDescription: product.description,
                price: product.price,
                rating: product.rating,
                thumbnailURLString: product.thumbnailURL?.absoluteString
            )
        )
        try modelContext.save()
        return true
    }

    public func fetchAll() async throws -> [Product] {
        let descriptor = FetchDescriptor<FavoriteProductRecord>(sortBy: [SortDescriptor(\.title)])
        return try modelContext.fetch(descriptor).map(Self.map)
    }

    public func remove(id: Int) async throws {
        guard let record = try fetchRecord(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchRecord(id: Int) throws -> FavoriteProductRecord? {
        var descriptor = FetchDescriptor<FavoriteProductRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private nonisolated static func map(_ record: FavoriteProductRecord) -> Product {
        Product(
            id: record.id,
            title: record.title,
            description: record.productDescription,
            price: record.price,
            rating: record.rating,
            thumbnailURL: record.thumbnailURLString.flatMap(URL.init(string:))
        )
    }
}

import Foundation

/// The local favorites cache. Shared by TWO features: `ProductDetailFeature` (toggles a
/// single product's favorite state) and `FavoritesFeature` (lists everything favorited)
/// both depend on `any FavoritesStoring` through `init` — never on
/// `SwiftDataFavoritesStore` (the SwiftData-backed implementation, owned by
/// `FavoritesFeature` — SwiftData is a feature-local persistence concern, not shared
/// vocabulary, so it stays out of `Domain`) directly.
public protocol FavoritesStoring: Sendable {
    func isFavorite(id: Int) async -> Bool

    /// Adds `product` if it isn't already favorited, removes it if it is.
    /// - Returns: The resulting favorite state (`true` = now favorited).
    @discardableResult
    func toggle(_ product: Product) async throws -> Bool

    func fetchAll() async throws -> [Product]

    func remove(id: Int) async throws
}

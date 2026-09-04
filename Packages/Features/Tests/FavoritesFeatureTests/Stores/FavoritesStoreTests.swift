import Domain
import Foundation
import SwiftData
import Testing

@testable import FavoritesFeature

/// `SwiftDataFavoritesStore` tested against a REAL `ModelContainer`, in memory only
/// (`isStoredInMemoryOnly: true`) — never a mock of SwiftData itself.
@Suite("SwiftDataFavoritesStore")
struct FavoritesStoreTests {
    private func makeStore() throws -> SwiftDataFavoritesStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FavoriteProductRecord.self, configurations: configuration)
        return SwiftDataFavoritesStore(modelContainer: container)
    }

    @Test("toggle(_:) adds a product, then toggling again removes it")
    func toggleAddsThenRemoves() async throws {
        let store = try makeStore()
        let product = Product(id: 1, title: "Round trip", description: "d", price: 9.99, rating: 4, thumbnailURL: nil)

        let added = try await store.toggle(product)
        #expect(added)
        #expect(await store.isFavorite(id: 1))

        let removed = try await store.toggle(product)
        #expect(removed == false)
        #expect(await store.isFavorite(id: 1) == false)
    }

    @Test("fetchAll() on an empty store returns an empty list")
    func fetchAllOnEmptyStoreReturnsEmpty() async throws {
        let store = try makeStore()

        let fetched = try await store.fetchAll()

        #expect(fetched.isEmpty)
    }

    @Test("fetchAll() round-trips a toggled product")
    func fetchAllRoundTripsToggledProduct() async throws {
        let store = try makeStore()
        let product = Product(id: 2, title: "Persisted", description: "d", price: 4.5, rating: 3, thumbnailURL: nil)

        try await store.toggle(product)
        let fetched = try await store.fetchAll()

        #expect(fetched == [product])
    }

    @Test("removeAll() empties the store")
    func removeAllEmptiesStore() async throws {
        let store = try makeStore()
        try await store.toggle(Product(id: 1, title: "A", description: "d", price: 1, rating: 1, thumbnailURL: nil))
        try await store.toggle(Product(id: 2, title: "B", description: "d", price: 2, rating: 2, thumbnailURL: nil))

        try await store.removeAll()

        let fetched = try await store.fetchAll()
        #expect(fetched.isEmpty)
    }
}

import Domain
import Foundation
import PlatformTestSupport
import Testing

@testable import FavoritesFeature

@Suite("FavoritesLogic")
struct FavoritesLogicTests {
    @Test("loadFavorites() returns what the store has")
    func loadFavoritesReturnsStoreContents() async throws {
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        let store = FavoritesStoreMock(allToReturn: [product])
        let logic = FavoritesLogic(favoritesStore: store)

        let items = try await logic.loadFavorites()

        #expect(items == [product])
    }

    @Test("A store failure maps to FavoritesError.storageFailure")
    func storeFailureMapsToStorageFailure() async {
        struct SomeStorageError: Error {}
        let store = FavoritesStoreMock()
        await store.setErrorToThrow(SomeStorageError())
        let logic = FavoritesLogic(favoritesStore: store)

        await #expect(throws: FavoritesError.storageFailure) {
            try await logic.loadFavorites()
        }
    }

    @Test("remove(id:) delegates to the store")
    func removeDelegatesToStore() async throws {
        let product = Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil)
        let store = FavoritesStoreMock(allToReturn: [product])
        let logic = FavoritesLogic(favoritesStore: store)

        try await logic.remove(id: 1)

        let remaining = try await store.fetchAll()
        #expect(remaining.isEmpty)
    }

    @Test("clearAll() delegates to the store's removeAll()")
    func clearAllDelegatesToStore() async throws {
        let products = [
            Product(id: 1, title: "A", description: "", price: 1, rating: 1, thumbnailURL: nil),
            Product(id: 2, title: "B", description: "", price: 2, rating: 2, thumbnailURL: nil)
        ]
        let store = FavoritesStoreMock(allToReturn: products)
        let logic = FavoritesLogic(favoritesStore: store)

        try await logic.clearAll()

        let remaining = try await store.fetchAll()
        #expect(remaining.isEmpty)
    }

    @Test("A store failure on clearAll() maps to FavoritesError.storageFailure")
    func clearAllFailureMapsToStorageFailure() async {
        struct SomeStorageError: Error {}
        let store = FavoritesStoreMock()
        await store.setErrorToThrow(SomeStorageError())
        let logic = FavoritesLogic(favoritesStore: store)

        await #expect(throws: FavoritesError.storageFailure) {
            try await logic.clearAll()
        }
    }
}

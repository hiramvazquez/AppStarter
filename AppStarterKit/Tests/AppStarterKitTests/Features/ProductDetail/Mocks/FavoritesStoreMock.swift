import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

/// Stub that substitutes `FavoritesStoring` — shared by `ProductDetailLogicTests` and
/// `FavoritesLogicTests`, exactly like the production `SwiftDataFavoritesStore` is shared
/// across those two features.
actor FavoritesStoreMock: FavoritesStoring {
    let toggleCalls = SpyRecorder<Int>()
    var isFavoriteToReturn = false
    var allToReturn: [Product] = []
    var errorToThrow: (any Error)?

    init(isFavoriteToReturn: Bool = false, allToReturn: [Product] = []) {
        self.isFavoriteToReturn = isFavoriteToReturn
        self.allToReturn = allToReturn
    }

    /// Actor-isolated state can't be assigned from outside (`store.errorToThrow = x` does
    /// not compile) — this is the setter a test awaits instead.
    func setErrorToThrow(_ error: (any Error)?) {
        errorToThrow = error
    }

    func isFavorite(id: Int) async -> Bool {
        isFavoriteToReturn
    }

    @discardableResult
    func toggle(_ product: Product) async throws -> Bool {
        await toggleCalls.record(product.id)
        if let errorToThrow { throw errorToThrow }
        isFavoriteToReturn.toggle()
        return isFavoriteToReturn
    }

    func fetchAll() async throws -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return allToReturn
    }

    func remove(id: Int) async throws {
        if let errorToThrow { throw errorToThrow }
        allToReturn.removeAll { $0.id == id }
    }
}

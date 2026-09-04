import AppFoundationTestSupport
import Domain
import Foundation

/// Stub that substitutes `FavoritesStoring` — shared by `ProductDetailFeatureTests` and
/// `FavoritesFeatureTests`, exactly like the production `SwiftDataFavoritesStore` (owned
/// by `FavoritesFeature`) is shared across those two features.
public actor FavoritesStoreMock: FavoritesStoring {
    public let toggleCalls = SpyRecorder<Int>()
    public var isFavoriteToReturn = false
    public var allToReturn: [Product] = []
    public var errorToThrow: (any Error)?

    public init(isFavoriteToReturn: Bool = false, allToReturn: [Product] = []) {
        self.isFavoriteToReturn = isFavoriteToReturn
        self.allToReturn = allToReturn
    }

    /// Actor-isolated state can't be assigned from outside (`store.errorToThrow = x` does
    /// not compile) — this is the setter a test awaits instead.
    public func setErrorToThrow(_ error: (any Error)?) {
        errorToThrow = error
    }

    public func isFavorite(id: Int) async -> Bool {
        isFavoriteToReturn
    }

    @discardableResult
    public func toggle(_ product: Product) async throws -> Bool {
        await toggleCalls.record(product.id)
        if let errorToThrow { throw errorToThrow }
        isFavoriteToReturn.toggle()
        return isFavoriteToReturn
    }

    public func fetchAll() async throws -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return allToReturn
    }

    public func remove(id: Int) async throws {
        if let errorToThrow { throw errorToThrow }
        allToReturn.removeAll { $0.id == id }
    }
}

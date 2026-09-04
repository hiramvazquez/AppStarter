import AppFoundationTestSupport
import Domain
import Foundation

@testable import FavoritesFeature

final class FavoritesLogicMock: FavoritesLogicProtocol {
    let removeCalls = SpyRecorder<Int>()
    var itemsToReturn: [Product] = []
    var errorToThrow: (any Error)?

    func loadFavorites() async throws -> [Product] {
        if let errorToThrow { throw errorToThrow }
        return itemsToReturn
    }

    func remove(id: Int) async throws {
        await removeCalls.record(id)
        if let errorToThrow { throw errorToThrow }
    }
}

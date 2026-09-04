import AppFoundationTestSupport
import Domain
import Foundation

@testable import FavoritesFeature

final class FavoritesLogicMock: FavoritesLogicProtocol {
    let removeCalls = SpyRecorder<Int>()
    let clearAllCalls = SpyRecorder<Void>()
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

    func clearAll() async throws {
        await clearAllCalls.record()
        if let errorToThrow { throw errorToThrow }
    }
}

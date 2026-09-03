import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

final class SearchLogicMock: SearchLogicProtocol {
    let searchCalls = SpyRecorder<String>()
    var resultsToReturn: [Product] = []
    var errorToThrow: (any Error)?

    func search(query: String) async throws -> [Product] {
        await searchCalls.record(query)
        if let errorToThrow { throw errorToThrow }
        return resultsToReturn
    }
}

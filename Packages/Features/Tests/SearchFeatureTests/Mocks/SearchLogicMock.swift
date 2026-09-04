import AppFoundationTestSupport
import Domain
import Foundation

@testable import SearchFeature

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
